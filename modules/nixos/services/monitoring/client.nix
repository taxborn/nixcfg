{
  config,
  lib,
  ...
}:
let

  monitoring = config.homelab.monitoring;
  inherit (monitoring) ports;

  hostname = config.networking.hostName;
  hostIP = config.homelab.tailscale.address;
  serverIP = config.homelab.hosts.${monitoring.server} or null;

  hasSmart = lib.elem hostname monitoring.physicalDisks;

  # direct-* only: those logs are credential-filtered. Keep rotated files out.
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

  # Tailnet address only. tailscale0 is trusted, so nothing is opened to the world.
  inherit (config.homelab.tailscale) bindOrdering;
in
{
  config = {
    assertions = [
      {
        assertion = hostIP != null && serverIP != null;
        message = ''
          The monitoring client runs on ${hostname}, but
          either it or the monitoring server (${monitoring.server}) has no entry
          in homelab.hosts. The exporters bind this host's
          address and Alloy pushes to the server's, so a missing entry is a host
          that silently exports nothing.
        '';
      }
      {
        # physicalDisks and smartd must agree, or SMART series silently go missing.
        assertion = hasSmart == config.services.smartd.enable;
        message = ''
          ${hostname} is ${if hasSmart then "" else "not "}listed in homelab.monitoring.physicalDisks, but
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

        enabledCollectors = [
          "systemd"

          "processes"

          "interrupts"
        ];
      };

      smartctl = lib.mkIf hasSmart {
        enable = true;
        listenAddress = hostIP;
        port = ports.smartctlExporter;

        devices = [ ];
      };
    };

    systemd.services = {
      prometheus-node-exporter = bindOrdering;
      prometheus-smartctl-exporter = lib.mkIf hasSmart bindOrdering;
    };

    services.alloy.enable = true;

    systemd.services.alloy.serviceConfig.SupplementaryGroups = lib.mkIf config.services.caddy.enable [
      config.services.caddy.group
    ];

    environment.etc."alloy/config.alloy" = {
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
