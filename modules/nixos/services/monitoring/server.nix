{
  config,
  lib,
  self,
  ...
}:
let

  monitoring = config.homelab.monitoring;
  inherit (monitoring) ports;
  grafana = config.homelab.services.grafana;

  hostname = config.networking.hostName;
  serverIP = config.homelab.tailscale.address;

  ntfyAuthFile = "/run/alertmanager-ntfy-auth/auth.yml";

  allHosts = lib.attrNames config.homelab.hosts;
  intermittentHosts = lib.subtractLists monitoring.alwaysOn allHosts;

  mkTargets =
    port: hosts:
    lib.mapAttrsToList (name: ip: {
      targets = [ "${ip}:${toString port}" ];
      labels.instance = name;
    }) (lib.filterAttrs (n: _: lib.elem n hosts) config.homelab.hosts);

  dashboardDir = "/etc/grafana-dashboards";

  promUID = "prometheus";
  lokiUID = "loki";
in
{
  imports = [
    ./alerts.nix
    ./dashboards.nix
  ];

  config = {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "modules/nixos/services/monitoring/server.nix binds Loki to a tailnet address, but services.tailscale.enable is false.";
      }
      {
        assertion = hostname == monitoring.server && serverIP != null;
        message = ''
          modules/nixos/services/monitoring/server.nix is enabled on ${hostname}, but
          homelab.monitoring.server names ${monitoring.server}. Every Alloy
          pushes to the host in the snippet, so the two have to be the same
          machine, and it needs a tailnet address to bind Loki to.
        '';
      }
      {
        assertion = lib.all (h: lib.elem h allHosts) (
          monitoring.alwaysOn ++ monitoring.physicalDisks ++ monitoring.minecraftHosts
        );
        message = "homelab.monitoring.alwaysOn, physicalDisks and minecraftHosts may only name hosts in homelab.hosts.";
      }
    ];

    age.secrets = {
      grafanaAdminPassword = {
        file = "${self}/secrets/grafana/admin-password.age";
        owner = "grafana";
        mode = "0400";
      };

      grafanaSecretKey = {
        file = "${self}/secrets/grafana/secret-key.age";
        owner = "grafana";
        mode = "0400";
      };

      ntfyToken = {
        file = "${self}/secrets/ntfy/token.age";
        mode = "0400";
      };
    };

    services.prometheus = {
      enable = true;

      # Loopback only. Exposing the TSDB on the tailnet would leak every host's metrics.
      listenAddress = "127.0.0.1";
      port = ports.prometheus;

      globalConfig = {
        scrape_interval = "30s";
        evaluation_interval = "30s";
      };

      retentionTime = "90d";
      extraFlags = [ "--storage.tsdb.retention.size=16GB" ];

      alertmanagers = [
        { static_configs = [ { targets = [ "127.0.0.1:${toString ports.alertmanager}" ]; } ]; }
      ];

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = mkTargets ports.nodeExporter monitoring.alwaysOn;
        }
        {
          job_name = "node-intermittent";
          static_configs = mkTargets ports.nodeExporter intermittentHosts;
        }
        {
          job_name = "smartctl";
          scrape_interval = "5m";
          static_configs = mkTargets ports.smartctlExporter monitoring.physicalDisks;
        }
        {
          job_name = "minecraft";
          static_configs = mkTargets ports.minecraftExporter monitoring.minecraftHosts;
        }
        {
          job_name = "minecraft-process";
          static_configs = mkTargets ports.processExporter monitoring.minecraftHosts;
        }
        {
          job_name = "prometheus";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString ports.prometheus}" ];
              labels.instance = hostname;
            }
          ];
        }
      ];
    };

    services.prometheus.alertmanager = {
      enable = true;

      # The module default listens on every interface.
      listenAddress = "127.0.0.1";
      port = ports.alertmanager;

      # Clustering would otherwise gossip on 9094 on every interface.
      extraFlags = [ "--cluster.listen-address=" ];

      configuration = {
        route = {
          receiver = "ntfy";

          group_by = [
            "alertname"
            "instance"
          ];

          group_wait = "30s";
          group_interval = "5m";

          repeat_interval = "12h";
        };

        receivers = [
          {
            name = "ntfy";
            webhook_configs = [
              {
                # Must be /hook. Any other path 404s and the alert is silently dropped.
                url = "http://127.0.0.1:${toString ports.alertmanagerNtfy}/hook";

                send_resolved = true;
              }
            ];
          }
        ];
      };
    };

    services.prometheus.alertmanager-ntfy = {
      enable = true;

      settings = {
        http.addr = "127.0.0.1:${toString ports.alertmanagerNtfy}";
        ntfy.baseurl = "https://${config.homelab.services.ntfy.domain}";
        ntfy.notification.topic = config.homelab.ntfy.topics.alerts;
      };

      extraConfigFiles = [ ntfyAuthFile ];
    };

    systemd.services = {
      alertmanager-ntfy-auth = {
        wantedBy = [ "multi-user.target" ];
        before = [ "alertmanager-ntfy.service" ];
        requiredBy = [ "alertmanager-ntfy.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          RuntimeDirectory = "alertmanager-ntfy-auth";
          RuntimeDirectoryMode = "0700";
          UMask = "0077";
        };
        script = ''
          printf 'ntfy:\n  auth:\n    token: "%s"\n' "$(< ${config.age.secrets.ntfyToken.path})" > ${ntfyAuthFile}
        '';
      };

      loki = config.homelab.tailscale.bindOrdering;
    };

    services.loki = {
      enable = true;

      configuration = {
        # Any tailnet peer can push any label. Accepted, see docs/monitoring.md.
        auth_enabled = false;

        server = {
          http_listen_address = serverIP;
          http_listen_port = ports.loki;

          grpc_listen_address = "127.0.0.1";
          grpc_listen_port = ports.lokiGrpc;

          log_level = "warn";
        };

        common = {
          path_prefix = "/var/lib/loki";
          replication_factor = 1;

          instance_addr = "127.0.0.1";

          ring = {
            instance_addr = "127.0.0.1";
            kvstore.store = "inmemory";
          };
          storage.filesystem = {
            chunks_directory = "/var/lib/loki/chunks";
            rules_directory = "/var/lib/loki/rules";
          };
        };

        schema_config.configs = [
          {
            from = "2026-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];

        storage_config.tsdb_shipper = {
          active_index_directory = "/var/lib/loki/tsdb-index";
          cache_location = "/var/lib/loki/tsdb-cache";
        };

        # Without retention_enabled the compactor never deletes and Loki fills the disk.
        compactor = {
          working_directory = "/var/lib/loki/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
          compaction_interval = "10m";
          retention_delete_delay = "2h";
        };

        limits_config = {
          retention_period = "30d";

          reject_old_samples = true;
          reject_old_samples_max_age = "168h";

          volume_enabled = true;

          ingestion_rate_mb = 8;
          ingestion_burst_size_mb = 16;
          max_streams_per_user = 5000;
        };

        ruler = {
          storage = {
            type = "local";
            local.directory = "/etc/loki/rules";
          };
          rule_path = "/var/lib/loki/rules-temp";
          alertmanager_url = "http://127.0.0.1:${toString ports.alertmanager}";
          enable_api = false;
          ring.kvstore.store = "inmemory";
        };

        analytics.reporting_enabled = false;
      };
    };

    environment.etc."loki/rules/fake/access.yaml".text = builtins.toJSON {
      groups = [
        {
          name = "http";
          rules = [
            {
              alert = "HttpLoginFailures";
              expr = ''
                sum by (host, vhost) (
                  count_over_time(
                    {job="caddy-access"} | json | status = 401 | request_uri =~ ".*createSession.*" [10m]
                  )
                ) > 10'';
              labels.severity = "warning";
              annotations = {
                summary = "failed logins on {{ $labels.vhost }} ({{ $labels.host }})";
                description = "{{ $value | printf \"%.0f\" }} failed logins in 10 minutes. Group by remote_ip in Explore.";
              };
            }
          ];
        }
      ];
    };

    services.grafana = {
      enable = true;

      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = grafana.port;
          inherit (grafana) domain;
          root_url = "https://${grafana.domain}/";
        };

        security = {
          # Declared rather than seeded, so the password is not mutable state.
          admin_password = "$__file{${config.age.secrets.grafanaAdminPassword.path}}";

          secret_key = "$__file{${config.age.secrets.grafanaSecretKey.path}}";

          cookie_secure = true;
          disable_gravatar = true;
        };

        users.allow_sign_up = false;

        analytics = {
          reporting_enabled = false;
          check_for_updates = false;
        };
      };

      provision = {
        datasources.settings = {
          deleteDatasources = [
            {
              name = "Prometheus";
              orgId = 1;
            }
            {
              name = "Loki";
              orgId = 1;
            }
          ];

          datasources = [
            {
              name = "Prometheus";
              uid = promUID;
              type = "prometheus";
              access = "proxy";
              url = "http://127.0.0.1:${toString ports.prometheus}";
              isDefault = true;
              jsonData.timeInterval = "30s";
            }
            {
              name = "Loki";
              uid = lokiUID;
              type = "loki";
              access = "proxy";
              url = "http://${serverIP}:${toString ports.loki}";
            }
          ];
        };

        dashboards.settings.providers = [
          {
            name = "default";
            orgId = 1;
            type = "file";
            updateIntervalSeconds = 30;

            allowUiUpdates = false;
            disableDeletion = true;

            options.path = dashboardDir;
          }
        ];
      };
    };

    # None of this belongs in an archive. See docs/monitoring.md.
    homelab.backups.extraExcludes = [
      "/var/lib/prometheus2"
      "/var/lib/loki"
      "/var/lib/grafana"
    ];
  };
}
