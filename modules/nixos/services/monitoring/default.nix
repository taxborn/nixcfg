{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.monitoring.client;

  tailnet = config.mySnippets.tailnet;
  ports = config.mySnippets.mischief-town.networkMap.monitoring;

  hostname = config.networking.hostName;
  hostIP = tailnet.tailscaleIPs.${hostname} or null;

  hasSmart = lib.elem hostname tailnet.physicalDisks;

  # Every listener here binds this host's own Tailscale address, and none of
  # these ports is in `allowedTCPPorts`. That is not an omission: the tailscale
  # module puts `tailscale0` in `trustedInterfaces`, so a socket on that address
  # is reachable from the tailnet and from nothing else. There is no listener on
  # Argon's or Carbon's public address for the firewall to have an opinion
  # about, which is the same reasoning the Forgejo module spells out for
  # binding loopback — loopback simply is not an option when the whole point is
  # that another host scrapes it.
  #
  # The cost is a startup ordering problem, handled by `tailnetBind` below.
  tailnetBind = {
    # `network.target` is up long before tailscaled has authenticated and
    # assigned an address, so a unit that wants a 100.64/10 address to bind can
    # and does lose that race on a cold boot. This orders the first attempt
    # after tailscaled, which usually wins it.
    after = [ "tailscaled.service" ];

    # And this is what actually makes it safe, because the ordering above is not
    # a guarantee: `tailscaled.service` being *started* does not mean an address
    # has been assigned yet. A losing attempt dies with EADDRNOTAVAIL, and these
    # units already default to `Restart = "always"`, so it retries — but
    # systemd's default rate limit of five starts in ten seconds will latch the
    # unit failed after a few seconds of trying and leave it dead until someone
    # notices. Dropping the limit turns a permanent failure into a few seconds
    # of retrying at boot.
    unitConfig.StartLimitIntervalSec = 0;
    serviceConfig.RestartSec = 5;
  };
in
{
  options.myNixOS.services.monitoring.client = {
    enable = lib.mkEnableOption "monitoring client (Prometheus exporters and Alloy log shipping)";

    logs = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = ''
        Ship this host's systemd journal to Loki through Alloy.

        Separate from `enable` because the two have different failure modes.
        Metrics are pulled: an unreachable host is a gap in a graph. Logs are
        pushed, and a host that cannot reach Loki buffers them, retries, and
        eventually drops them — noise in the journal of the host least able to
        afford it. Turning this off leaves metrics working.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = hostIP != null;
        message = ''
          myNixOS.services.monitoring.client is enabled on ${hostname}, but that
          host has no entry in mySnippets.tailnet.tailscaleIPs. The exporters
          bind that address and the monitoring server derives its scrape targets
          from the same map, so a missing entry is a host that silently exports
          nothing and is never scraped.
        '';
      }
      {
        # These two answer the same question — does this machine have disks
        # worth asking about — from opposite ends of the config, and nothing
        # else would catch them disagreeing. A host in `physicalDisks` with
        # smartd off exports no SMART series while the server scrapes for them;
        # a host out of it with smartd on has the data and never publishes it.
        assertion = hasSmart == config.services.smartd.enable;
        message = ''
          ${hostname} is ${
            if hasSmart then "" else "not "
          }listed in mySnippets.tailnet.physicalDisks, but services.smartd.enable
          is ${lib.boolToString config.services.smartd.enable}. Both describe
          whether this host has SMART-capable disks and they have to agree.
        '';
      }
    ];

    services.prometheus.exporters = {
      node = {
        enable = true;
        listenAddress = hostIP;
        port = ports.nodeExporter.port;

        # On top of the default set, which already covers what a fleet dashboard
        # wants: cpu, meminfo, diskstats, filesystem, netdev, hwmon, and — the
        # two that matter most on these hosts — btrfs and mdadm.
        enabledCollectors = [
          # The highest-value collector here by a distance. It exports a state
          # series per unit, which turns every failure this config can already
          # have into one alert rule: a backup that did not run, a runner that
          # died, a Caddy that would not start. Without it, `borgmatic.service`
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

      # Reads SMART attributes directly off the block devices, which is why the
      # nixpkgs module gives it CAP_SYS_RAWIO, CAP_SYS_ADMIN and the `disk`
      # group rather than running it unprivileged. Nothing to add here.
      #
      # Enabled only where there are disks to read: `hardware/profiles/ovh.nix`
      # turns smartd off on the VPSes because virtio devices answer no SMART
      # command, and an exporter there would publish an empty result set for the
      # server to scrape forever.
      smartctl = lib.mkIf hasSmart {
        enable = true;
        listenAddress = hostIP;
        port = ports.smartctlExporter.port;

        # Left empty so the exporter scans for devices itself. Naming them would
        # pin /dev/sdX paths that are not stable across boots, and would need
        # editing per host — the scan finds the mdraid members on the
        # workstations and the external drive on Helium without being told.
        devices = [ ];
      };
    };

    systemd.services = {
      prometheus-node-exporter = tailnetBind;
      prometheus-smartctl-exporter = lib.mkIf hasSmart tailnetBind;
    };

    services.alloy.enable = cfg.logs;

    # Written to /etc rather than passed as a store path through `configPath`.
    # The nixpkgs module builds `reloadTriggers` by scanning
    # `environment.etc."alloy/*.alloy"`, and documents a store path as the
    # fallback "at the cost of reload" — so the store-path form, which is what
    # this config used to do, gets a full restart of the log shipper on every
    # unrelated rebuild instead of a SIGHUP.
    environment.etc."alloy/config.alloy" = lib.mkIf cfg.logs {
      text = ''
        // Journal entries only. No file scraping: everything on these hosts
        // logs to the journal, including Caddy's runtime log, and the one thing
        // that does not — Caddy's per-vhost access logs — is already watched by
        // fail2ban and would be a large, low-value stream to duplicate here.
        loki.source.journal "journal" {
          forward_to    = [loki.write.argon.receiver]
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

        loki.write "argon" {
          endpoint {
            url = "http://${tailnet.tailscaleIPs.argon}:${toString ports.loki.port}/loki/api/v1/push"
          }
        }
      '';
    };
  };
}
