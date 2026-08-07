{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myNixOS.services.monitoring.server;

  # Must match the UIDs pinned on the provisioned datasources in server.nix.
  # Pinning them is what lets a dashboard name its datasource at build time
  # instead of asking the reader to pick one from a dropdown.
  promUID = "prometheus";
  lokiUID = "loki";

  prom = {
    type = "prometheus";
    uid = promUID;
  };
  lokiDs = {
    type = "loki";
    uid = lokiUID;
  };

  # Real filesystems only, matching the selector the alert rules use. Kept in
  # step with alerts.nix by hand — they are separate files because a dashboard
  # is not an alert, but a graph that disagrees with the rule that pages you is
  # worse than either alone.
  realFs = ''fstype=~"btrfs|ext4|xfs|vfat|ntfs3|fuseblk"'';

  refIds = lib.stringToCharacters "ABCDEFGHIJKL";

  steps = pairs: {
    mode = "absolute";
    steps = pairs;
  };
  step = color: value: { inherit color value; };

  mkPanel =
    {
      type,
      title,
      gridPos,
      ds ? prom,
      targets ? [ ],
      unit ? null,
      min ? null,
      max ? null,
      decimals ? null,
      thresholds ? null,
      colorMode ? null,
      options ? { },
      custom ? { },
      overrides ? [ ],
      description ? null,
    }:
    {
      inherit
        type
        title
        gridPos
        options
        ;
      datasource = ds;

      targets = lib.imap0 (
        i: t:
        {
          refId = lib.elemAt refIds i;
          datasource = ds;
          inherit (t) expr;
          legendFormat = t.legend or "";
        }
        // (t.extra or { })
      ) targets;

      fieldConfig = {
        defaults = {
          inherit custom;
        }
        // lib.optionalAttrs (unit != null) { inherit unit; }
        // lib.optionalAttrs (min != null) { inherit min; }
        // lib.optionalAttrs (max != null) { inherit max; }
        // lib.optionalAttrs (decimals != null) { inherit decimals; }
        // lib.optionalAttrs (thresholds != null) { inherit thresholds; }
        // lib.optionalAttrs (colorMode != null) { color.mode = colorMode; };
        inherit overrides;
      };
    }
    // lib.optionalAttrs (description != null) { inherit description; };

  # A line graph. `mode = "multi"` on the tooltip is the setting that makes a
  # fleet-wide graph readable: hovering shows every host at that instant rather
  # than only the series the cursor happens to be nearest.
  ts =
    args:
    mkPanel (
      {
        type = "timeseries";
        options = {
          legend = {
            displayMode = "list";
            placement = "bottom";
            showLegend = true;
          };
          tooltip = {
            mode = "multi";
            sort = "desc";
          };
        };
        custom = {
          lineWidth = 1;
          fillOpacity = 8;
          showPoints = "never";
        };
      }
      // args
    );

  stat =
    args:
    mkPanel (
      {
        type = "stat";
        colorMode = "thresholds";
        options = {
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          colorMode = "background";
          graphMode = "none";
          textMode = "auto";
          justifyMode = "center";
        };
      }
      // args
    );

  bar =
    args:
    mkPanel (
      {
        type = "bargauge";
        colorMode = "thresholds";
        options = {
          reduceOptions = {
            calcs = [ "lastNotNull" ];
            fields = "";
            values = false;
          };
          displayMode = "gradient";
          orientation = "horizontal";
          showUnfilled = true;
        };
      }
      // args
    );

  mkDashboard =
    {
      uid,
      title,
      description,
      tags,
      panels,
      templating ? [ ],
      refresh ? "1m",
      from ? "now-6h",
    }:
    pkgs.writeText "grafana-dashboard-${uid}.json" (
      builtins.toJSON {
        inherit
          uid
          title
          description
          tags
          panels
          refresh
          ;

        # Null rather than a number: a provisioned dashboard must not claim an
        # internal id, which belongs to whatever database it is loaded into.
        id = null;

        schemaVersion = 39;
        version = 1;
        timezone = "browser";

        # The provisioning provider already sets allowUiUpdates = false, so an
        # edit in the browser would be accepted and then silently discarded on
        # the next restart. Marking the dashboard itself read-only means the UI
        # says so up front instead.
        editable = false;

        time = {
          inherit from;
          to = "now";
        };
        templating.list = templating;
      }
    );

  # --------------------------------------------------------- upstream dashboards

  # Fetched at build time against a pinned revision and hash, rather than
  # vendored into the repo. The previous version of this stack checked the same
  # dashboard in as a 470 KB, 15,597-line JSON blob, which made every upstream
  # bump a 15,000-line diff nobody could review. This is the treatment the Caddy
  # plugins already get in modules/nixos/services/caddy.nix: a version bump is a
  # revision number and a hash.
  #
  # Refresh with:
  #   curl -s https://grafana.com/api/dashboards/1860 | jq .revision
  #   nix store prefetch-file https://grafana.com/api/dashboards/1860/revisions/<n>/download
  grafanaDashboard =
    {
      id,
      revision,
      hash,
      name,
    }:
    pkgs.runCommand "grafana-dashboard-${name}.json"
      {
        nativeBuildInputs = [ pkgs.jq ];
        src = pkgs.fetchurl {
          url = "https://grafana.com/api/dashboards/${toString id}/revisions/${toString revision}/download";
          inherit hash;
        };
      }
      ''
        # Upstream ships the datasource as a *picker* variable with an empty
        # `current`, so the dashboard renders blank until someone chooses from a
        # dropdown — and that choice is then stored per-user in Grafana's
        # mutable database rather than in this file, so it does not survive a
        # new browser or a new user. Binding it to the provisioned UID and
        # hiding the picker (`hide: 2`) is what makes the dashboard work on
        # first load, which is the whole reason this jq pass exists.
        jq --arg uid ${promUID} '
          (.templating.list[]? | select(.type == "datasource" and .query == "prometheus"))
            |= (.current = { text: "Prometheus", value: $uid } | .hide = 2)
          | .id = null
        ' "$src" > "$out"
      '';

  nodeExporterFull = grafanaDashboard {
    name = "node-exporter-full";
    id = 1860;
    revision = 45;
    hash = "sha256-GExrdAnzBtp1Ul13cvcZRbEM6iOtFrXXjEaY6g6lGYY=";
  };

  # ------------------------------------------------------------- fleet overview

  # The single pane the upstream dashboard cannot give: 1860 is deliberately
  # one-host-at-a-time, driven by a `$node` picker, so there is nowhere in it
  # that answers "is anything wrong anywhere".
  fleetOverview = mkDashboard {
    uid = "fleet-overview";
    title = "Fleet Overview";
    description = "Every host at once: reachability, saturation, and what is currently firing.";
    tags = [
      "fleet"
      "overview"
    ];

    panels = [
      (stat {
        title = "Hosts reachable";
        gridPos = {
          h = 4;
          w = 6;
          x = 0;
          y = 0;
        };
        targets = [ { expr = ''count(up{job=~"node.*"} == 1)''; } ];
        thresholds = steps [
          (step "red" null)
          (step "green" 1)
        ];
      })

      (stat {
        title = "Firing alerts";
        description = "Prometheus publishes its own alert state as the ALERTS series, so this needs no extra plumbing.";
        gridPos = {
          h = 4;
          w = 6;
          x = 6;
          y = 0;
        };
        # `or vector(0)` because a series that matches nothing is *absent*, not
        # zero — without it this panel reads "No data" in the one state that
        # matters most, which is everything being fine.
        targets = [ { expr = ''count(ALERTS{alertstate="firing"}) or vector(0)''; } ];
        thresholds = steps [
          (step "green" null)
          (step "red" 1)
        ];
      })

      (stat {
        title = "Failed units";
        gridPos = {
          h = 4;
          w = 6;
          x = 12;
          y = 0;
        };
        targets = [ { expr = ''count(node_systemd_unit_state{state="failed"} == 1) or vector(0)''; } ];
        thresholds = steps [
          (step "green" null)
          (step "red" 1)
        ];
      })

      (stat {
        title = "Degraded arrays";
        gridPos = {
          h = 4;
          w = 6;
          x = 18;
          y = 0;
        };
        targets = [ { expr = "count(node_md_degraded > 0) or vector(0)"; } ];
        thresholds = steps [
          (step "green" null)
          (step "red" 1)
        ];
      })

      (bar {
        title = "CPU busy";
        gridPos = {
          h = 8;
          w = 8;
          x = 0;
          y = 4;
        };
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = ''100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
            legend = "{{instance}}";
          }
        ];
        thresholds = steps [
          (step "green" null)
          (step "yellow" 70)
          (step "red" 90)
        ];
      })

      (bar {
        title = "Memory used";
        gridPos = {
          h = 8;
          w = 8;
          x = 8;
          y = 4;
        };
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = "100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)";
            legend = "{{instance}}";
          }
        ];
        thresholds = steps [
          (step "green" null)
          (step "yellow" 80)
          (step "red" 90)
        ];
      })

      (bar {
        title = "Fullest filesystem";
        description = "Worst filesystem per host. btrfs subvolumes share a pool and report identical figures, so this collapses on device the way the alert rules do.";
        gridPos = {
          h = 8;
          w = 8;
          x = 16;
          y = 4;
        };
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = ''
              100 * (1 - min by (instance) (
                node_filesystem_avail_bytes{${realFs}} / node_filesystem_size_bytes{${realFs}}
              ))'';
            legend = "{{instance}}";
          }
        ];
        thresholds = steps [
          (step "green" null)
          (step "yellow" 80)
          (step "red" 90)
        ];
      })

      (ts {
        title = "CPU busy";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 12;
        };
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = ''100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)'';
            legend = "{{instance}}";
          }
        ];
      })

      (ts {
        title = "Memory available";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 12;
        };
        unit = "bytes";
        min = 0;
        targets = [
          {
            expr = "node_memory_MemAvailable_bytes";
            legend = "{{instance}}";
          }
        ];
      })

      (ts {
        title = "Network received";
        description = "Physical interfaces only — loopback and the tailscale, podman and veth interfaces would double-count the same traffic.";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 20;
        };
        unit = "Bps";
        min = 0;
        targets = [
          {
            expr = ''sum by (instance) (rate(node_network_receive_bytes_total{device!~"lo|tailscale.*|veth.*|podman.*|docker.*|br-.*"}[5m]))'';
            legend = "{{instance}}";
          }
        ];
      })

      (ts {
        title = "Network transmitted";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 20;
        };
        unit = "Bps";
        min = 0;
        targets = [
          {
            expr = ''sum by (instance) (rate(node_network_transmit_bytes_total{device!~"lo|tailscale.*|veth.*|podman.*|docker.*|br-.*"}[5m]))'';
            legend = "{{instance}}";
          }
        ];
      })

      (ts {
        title = "Disk read";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 28;
        };
        unit = "Bps";
        min = 0;
        targets = [
          {
            expr = "sum by (instance) (rate(node_disk_read_bytes_total[5m]))";
            legend = "{{instance}}";
          }
        ];
      })

      (ts {
        title = "Disk written";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 28;
        };
        unit = "Bps";
        min = 0;
        targets = [
          {
            expr = "sum by (instance) (rate(node_disk_written_bytes_total[5m]))";
            legend = "{{instance}}";
          }
        ];
      })

      (mkPanel {
        type = "table";
        title = "Firing alerts";
        gridPos = {
          h = 8;
          w = 24;
          x = 0;
          y = 36;
        };
        options = {
          showHeader = true;
          sortBy = [
            {
              displayName = "alertname";
              desc = false;
            }
          ];
        };
        targets = [
          {
            expr = ''ALERTS{alertstate="firing"}'';
            extra = {
              instant = true;
              format = "table";
            };
          }
        ];
        overrides = [ ];
      })
    ];
  };

  # ----------------------------------------------------------------- disk & SMART

  diskSmart = mkDashboard {
    uid = "disk-smart";
    title = "Disk & SMART";
    description = "Drive health, wear and capacity across the fleet. Sourced from smartctl_exporter, which only runs where there are real disks.";
    tags = [
      "fleet"
      "disk"
      "smart"
    ];

    panels = [
      (stat {
        title = "Drives reporting SMART failure";
        gridPos = {
          h = 4;
          w = 8;
          x = 0;
          y = 0;
        };
        targets = [ { expr = "count(smartctl_device_smart_status == 0) or vector(0)"; } ];
        thresholds = steps [
          (step "green" null)
          (step "red" 1)
        ];
      })

      (stat {
        title = "Read-only filesystems";
        gridPos = {
          h = 4;
          w = 8;
          x = 8;
          y = 0;
        };
        targets = [ { expr = "count(node_filesystem_readonly{${realFs}} == 1) or vector(0)"; } ];
        thresholds = steps [
          (step "green" null)
          (step "red" 1)
        ];
      })

      (stat {
        title = "btrfs errors (24h)";
        gridPos = {
          h = 4;
          w = 8;
          x = 16;
          y = 0;
        };
        targets = [ { expr = "sum(increase(node_btrfs_device_errors_total[24h])) or vector(0)"; } ];
        thresholds = steps [
          (step "green" null)
          (step "red" 1)
        ];
      })

      (ts {
        title = "Drive temperature";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 4;
        };
        unit = "celsius";
        targets = [
          {
            expr = ''smartctl_device_temperature{temperature_type="current"}'';
            legend = "{{instance}} {{device}}";
          }
        ];
      })

      (bar {
        title = "NVMe life used";
        description = "Percentage of rated write endurance consumed. Can exceed 100 without the drive failing.";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 4;
        };
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = "smartctl_device_percentage_used";
            legend = "{{instance}} {{device}}";
          }
        ];
        thresholds = steps [
          (step "green" null)
          (step "yellow" 70)
          (step "red" 85)
        ];
      })

      (bar {
        title = "Available spare";
        description = "Spare blocks left for remapping, as a percentage. The alert fires when this drops under the drive's own threshold rather than a number picked here.";
        gridPos = {
          h = 8;
          w = 12;
          x = 0;
          y = 12;
        };
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = "smartctl_device_available_spare";
            legend = "{{instance}} {{device}}";
          }
        ];
        thresholds = steps [
          (step "red" null)
          (step "yellow" 20)
          (step "green" 50)
        ];
      })

      (bar {
        title = "Power-on time";
        gridPos = {
          h = 8;
          w = 12;
          x = 12;
          y = 12;
        };
        unit = "s";
        targets = [
          {
            expr = "smartctl_device_power_on_seconds";
            legend = "{{instance}} {{device}}";
          }
        ];
        thresholds = steps [ (step "blue" null) ];
      })

      (bar {
        title = "Filesystem used";
        description = "Every mounted filesystem. Unlike the fleet overview this does not collapse btrfs subvolumes, so the repeated pool figures are expected.";
        gridPos = {
          h = 10;
          w = 12;
          x = 0;
          y = 20;
        };
        unit = "percent";
        min = 0;
        max = 100;
        targets = [
          {
            expr = "100 * (1 - node_filesystem_avail_bytes{${realFs}} / node_filesystem_size_bytes{${realFs}})";
            legend = "{{instance}} {{mountpoint}}";
          }
        ];
        thresholds = steps [
          (step "green" null)
          (step "yellow" 80)
          (step "red" 90)
        ];
      })

      (ts {
        title = "Disk I/O utilisation";
        description = "Fraction of wall time the device spent servicing requests. Sustained near 100% means the disk is the bottleneck.";
        gridPos = {
          h = 10;
          w = 12;
          x = 12;
          y = 20;
        };
        unit = "percentunit";
        min = 0;
        max = 1;
        targets = [
          {
            expr = "rate(node_disk_io_time_seconds_total[5m])";
            legend = "{{instance}} {{device}}";
          }
        ];
      })

      (ts {
        title = "btrfs device errors";
        gridPos = {
          h = 8;
          w = 24;
          x = 0;
          y = 30;
        };
        min = 0;
        targets = [
          {
            expr = "increase(node_btrfs_device_errors_total[1h])";
            legend = "{{instance}} {{device}} {{type}}";
          }
        ];
      })
    ];
  };

  # ------------------------------------------------------------------------ logs

  logs = mkDashboard {
    uid = "fleet-logs";
    title = "Logs";
    description = "Systemd journal from every host, shipped by Alloy into Loki.";
    tags = [
      "fleet"
      "logs"
    ];
    from = "now-1h";
    refresh = "";

    # `host` and `unit` are the two labels Alloy promotes — see the relabel
    # rules in this directory's default.nix. Nothing else is a label, so nothing
    # else can be a variable here.
    templating = [
      {
        name = "host";
        label = "Host";
        type = "query";
        datasource = lokiDs;
        query = "label_values(host)";
        refresh = 1;
        includeAll = true;
        multi = true;
        current = {
          text = "All";
          value = "$__all";
        };
      }
      {
        name = "unit";
        label = "Unit";
        type = "query";
        datasource = lokiDs;
        query = ''label_values({host=~"$host"}, unit)'';
        refresh = 2;
        includeAll = true;
        multi = true;
        current = {
          text = "All";
          value = "$__all";
        };
      }
      {
        name = "search";
        label = "Contains";
        type = "textbox";
        query = "";
        current = {
          text = "";
          value = "";
        };
      }
    ];

    panels = [
      (ts {
        title = "Log volume by level";
        gridPos = {
          h = 6;
          w = 24;
          x = 0;
          y = 0;
        };
        ds = lokiDs;
        min = 0;
        custom = {
          drawStyle = "bars";
          fillOpacity = 60;
          stacking.mode = "normal";
          lineWidth = 0;
        };
        targets = [
          {
            expr = ''sum by (level) (count_over_time({host=~"$host", unit=~"$unit"} |~ "(?i)$search" [$__auto]))'';
            legend = "{{level}}";
          }
        ];
      })

      (mkPanel {
        type = "logs";
        title = "Journal";
        gridPos = {
          h = 22;
          w = 24;
          x = 0;
          y = 6;
        };
        ds = lokiDs;
        options = {
          showTime = true;
          showLabels = false;
          showCommonLabels = false;
          wrapLogMessage = true;
          prettifyLogMessage = false;
          enableLogDetails = true;
          dedupStrategy = "none";
          sortOrder = "Descending";
        };
        targets = [
          {
            # `(?i)` on an empty $search matches everything, so the textbox is
            # inert until it is typed in — no separate "filtered" panel needed.
            expr = ''{host=~"$host", unit=~"$unit"} |~ "(?i)$search"'';
          }
        ];
      })
    ];
  };

  dashboards = {
    "node-exporter-full" = nodeExporterFull;
    "fleet-overview" = fleetOverview;
    "disk-smart" = diskSmart;
    "logs" = logs;
  };
in
{
  config = lib.mkIf cfg.enable {
    environment.etc = lib.mapAttrs' (
      name: file:
      lib.nameValuePair "grafana-dashboards/${name}.json" {
        source = file;
        # Grafana's provisioner reads these as its own user.
        mode = "0444";
      }
    ) dashboards;
  };
}
