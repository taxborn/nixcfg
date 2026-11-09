{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.monitoring.client;

  tailnet = config.mySnippets.tailnet;
  monitoring = config.mySnippets.monitoring;
  inherit (monitoring) ports;

  hostname = config.networking.hostName;
  hostIP = config.myNixOS.services.tailscale.address;
  serverIP = tailnet.tailscaleIPs.${monitoring.server} or null;

  hasSmart = lib.elem hostname monitoring.physicalDisks;

  # Only the `direct-*` logs, which the direct vhosts on Argon write with
  # credentials filtered out and group-readable (hosts/argon/proxy.nix). The
  # `access-*` defaults are unfiltered, 0600, and Cloudflare's traffic, so the
  # prefix keeps them out. fail2ban no longer reads any of them.
  #
  # Two labels, both bounded. `vhost` comes from the file name, so it is the
  # number of vhosts with a log. Everything else stays inside the JSON line
  # for `| json` at query time: status, remote_ip and the URI as labels would
  # make one stream per client, which is the cardinality blow-up
  # `max_streams_per_user` exists to stop.
  #
  # Rotated files (`direct-x-2026-11-09T...log`) match the same glob, and a new
  # path is read from the start, so they are excluded or every rotation would
  # re-ship a day of logs.
  caddyAccess = lib.optionalString config.services.caddy.enable ''
    local.file_match "caddy_access" {
      path_targets = [{
        __path__         = "${config.services.caddy.logDir}/direct-*.log",
        __path_exclude__ = "${config.services.caddy.logDir}/*-[0-9][0-9][0-9][0-9]-[0-9][0-9]-*",
        job              = "caddy-access",
        host             = "${hostname}",
      }]
    }

    discovery.relabel "caddy_access" {
      targets = local.file_match.caddy_access.targets

      rule {
        source_labels = ["__path__"]
        regex         = ".*/direct-(.+)\\.log"
        target_label  = "vhost"
      }
    }

    loki.source.file "caddy_access" {
      targets    = discovery.relabel.caddy_access.output
      forward_to = [loki.write.server.receiver]
    }
  '';

  # Every listener here binds this host's own Tailscale address, and none of
  # these ports is in `allowedTCPPorts`. The tailscale module puts `tailscale0`
  # in `trustedInterfaces`, so a socket on that address is reachable from the
  # tailnet and from nothing else. Loopback is not an option when the point is
  # that another host scrapes it.
  #
  # The cost is a startup ordering problem, handled by
  # `myNixOS.services.tailscale.bindOrdering`, which documents the race.
  inherit (config.myNixOS.services.tailscale) bindOrdering;
in
{
  options.myNixOS.services.monitoring.client = {
    enable = lib.mkEnableOption "monitoring client (Prometheus exporters and Alloy log shipping)";

    logs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Ship this host's systemd journal to Loki through Alloy.

        Separate from `enable` because the two fail differently. Metrics are
        pulled, so an unreachable host is a gap in a graph. Logs are pushed, and
        a host that cannot reach Loki retries and eventually drops them, which
        is noise in the journal of the host least able to afford it. Turning
        this off leaves metrics working.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = hostIP != null && serverIP != null;
        message = ''
          myNixOS.services.monitoring.client is enabled on ${hostname}, but
          either it or the monitoring server (${monitoring.server}) has no entry
          in mySnippets.tailnet.tailscaleIPs. The exporters bind this host's
          address and Alloy pushes to the server's, so a missing entry is a host
          that silently exports nothing.
        '';
      }
      {
        # These answer the same question, whether this machine has disks worth
        # asking about, from opposite ends of the config, and nothing else would
        # catch them disagreeing. A host in `physicalDisks` with smartd off
        # exports no SMART series while the server scrapes for them; a host out
        # of it with smartd on has the data and never publishes it.
        assertion = hasSmart == config.services.smartd.enable;
        message = ''
          ${hostname} is ${if hasSmart then "" else "not "}listed in mySnippets.monitoring.physicalDisks, but
          services.smartd.enable is ${lib.boolToString config.services.smartd.enable}.
          Both describe whether this host has SMART-capable disks and they have
          to agree.
        '';
      }
    ];

    services.prometheus.exporters = {
      node = {
        enable = true;
        listenAddress = hostIP;
        port = ports.nodeExporter;

        # On top of the default set, which already covers cpu, meminfo,
        # diskstats, filesystem, netdev, hwmon and, the two that matter most on
        # these hosts, btrfs and mdadm.
        enabledCollectors = [
          # The highest-value collector by a distance. It exports a state series
          # per unit, which turns every failure this config can already have
          # into one alert rule: a backup that did not run, a runner that died,
          # a Caddy that would not start. Without it, `borgmatic.service`
          # failing is visible only to whoever runs `systemctl --failed`.
          "systemd"

          # Process counts and states, which is how a fork bomb or a pile of
          # stuck D-state processes shows up before the machine stops answering.
          "processes"

          # Per-CPU interrupt counts. Cheap, and the thing to look at when a
          # host is busy with no process to blame.
          "interrupts"
        ];
      };

      # Reads SMART attributes straight off the block devices, which is why the
      # nixpkgs module gives it CAP_SYS_RAWIO, CAP_SYS_ADMIN and the `disk`
      # group. Only enabled where there are disks to read, for the reason
      # `physicalDisks` documents.
      smartctl = lib.mkIf hasSmart {
        enable = true;
        listenAddress = hostIP;
        port = ports.smartctlExporter;

        # Left empty so the exporter scans for devices itself. Naming them would
        # pin /dev/sdX paths that are not stable across boots and would need
        # editing per host. The scan finds the mdraid members on the
        # workstations and the external drive on Helium without being told.
        devices = [ ];
      };
    };

    systemd.services = {
      prometheus-node-exporter = bindOrdering;
      prometheus-smartctl-exporter = lib.mkIf hasSmart bindOrdering;
    };

    services.alloy.enable = cfg.logs;

    # The access logs are `caddy:caddy` 0640. Alloy runs as a DynamicUser and
    # would otherwise get a permission error that only shows up as a missing
    # stream in Loki.
    systemd.services.alloy.serviceConfig.SupplementaryGroups = lib.mkIf (
      cfg.logs && config.services.caddy.enable
    ) [ config.services.caddy.group ];

    # Written to /etc rather than passed as a store path through `configPath`.
    # The nixpkgs module builds `reloadTriggers` by scanning
    # `environment.etc."alloy/*.alloy"`, so the store-path form gets a full
    # restart of the log shipper on every unrelated rebuild instead of a SIGHUP.
    environment.etc."alloy/config.alloy" = lib.mkIf cfg.logs {
      text = ''
        // The journal, plus Caddy's access logs where Caddy runs (below).
        // Everything else on these hosts logs to the journal, Caddy's runtime
        // log included.
        //
        // Alloy keeps a cursor in /var/lib/alloy, so a laptop that was off the
        // tailnet resumes where it stopped instead of losing the gap. Loki
        // refuses anything older than a week, which bounds the backlog.
        loki.source.journal "journal" {
          forward_to    = [loki.write.server.receiver]
          relabel_rules = loki.relabel.journal.rules

          labels = {
            job  = "systemd-journal",
            host = "${hostname}",
          }
        }

        // Journal fields arrive as `__journal_*` and are dropped unless
        // promoted here, because every label is a separate stream in Loki and
        // promoting a high-cardinality field is how a small Loki falls over.
        // These two are bounded: the set of units on a host, and the eight
        // syslog priorities.
        loki.relabel "journal" {
          forward_to = []

          rule {
            source_labels = ["__journal__systemd_unit"]
            target_label  = "unit"
          }

          rule {
            source_labels = ["__journal_priority_keyword"]
            target_label  = "level"
          }
        }

        ${caddyAccess}
        loki.write "server" {
          endpoint {
            url = "http://${serverIP}:${toString ports.loki}/loki/api/v1/push"
          }
        }
      '';
    };
  };
}
