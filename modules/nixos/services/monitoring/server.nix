{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.monitoring.server;

  tailnet = config.mySnippets.tailnet;
  ports = config.mySnippets.mischief-town.networkMap.monitoring;

  argonIP = tailnet.tailscaleIPs.argon;

  # The roster, partitioned. Every host on the tailnet is scraped; the split
  # only decides which job a host lands in, and the job is what the down alert
  # keys off. See `mySnippets.tailnet.alwaysOn`.
  allHosts = lib.attrNames tailnet.tailscaleIPs;
  intermittentHosts = lib.subtractLists tailnet.alwaysOn allHosts;

  # One `static_configs` entry per host, each carrying its own `instance` label
  # so graphs and alerts read `helium` rather than `100.64.1.0:9100`. Safe as a
  # per-target label rather than a relabel rule only because each entry has
  # exactly one target — two targets sharing one entry would collapse to the
  # same instance and silently overwrite each other's series.
  mkTargets =
    port: hosts:
    lib.mapAttrsToList
      (name: ip: {
        targets = [ "${ip}:${toString port}" ];
        labels.instance = name;
      })
      (
        # `filterAttrs` over the roster rather than `map` over the host list, so
        # a name in `alwaysOn` or `physicalDisks` that is not on the tailnet is
        # dropped instead of producing a target with an empty address.
        lib.filterAttrs (n: _: lib.elem n hosts) tailnet.tailscaleIPs
      );

  dashboardDir = "/etc/grafana-dashboards";

  # Datasource UIDs are pinned rather than left for Grafana to generate, because
  # provisioned dashboards have to name them at build time. The alternative is
  # what the previous version of this stack shipped: dashboards carrying a
  # datasource *picker* variable with no default, which renders an empty screen
  # until someone chooses from a dropdown, and stores that choice per-user in
  # the mutable database rather than in the provisioned JSON.
  promUID = "prometheus";
  lokiUID = "loki";
in
{
  options.myNixOS.services.monitoring.server = {
    enable = lib.mkEnableOption "monitoring server (Prometheus, Loki, Grafana, Alertmanager)";

    ntfyBaseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://ntfy.sh";
      example = "https://ntfy.mischief.town";
      description = ''
        Base URL of the ntfy instance alerts are published to.

        The topic is not set here and deliberately cannot be: on a public
        instance the topic name is the only thing standing between an alert
        stream and anyone who guesses it, which makes it a password rather than
        a setting. It arrives through the agenix secret below instead, so it
        never has a Nix store path.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "myNixOS.services.monitoring.server binds Loki to a tailnet address, but services.tailscale.enable is false.";
      }
    ];

    age.secrets = {
      # Grafana reads both of these itself, at startup, through the `$__file{}`
      # indirection below — so unlike the credentials pattern used for the
      # Forgejo runner, the process needs to be able to open them directly.
      grafanaAdminPassword = {
        file = "${self}/secrets/grafana/admin-password.age";
        owner = "grafana";
        mode = "0400";
      };

      # Signs Grafana's own session cookies and encrypts the datasource
      # credentials it stores. Losing it invalidates every session; changing it
      # is harmless beyond that, since nothing here stores a secret in Grafana.
      grafanaSecretKey = {
        file = "${self}/secrets/grafana/secret-key.age";
        owner = "grafana";
        mode = "0400";
      };

      # Read by systemd as root and passed to the bridge through
      # LoadCredential — the unit runs under DynamicUser, so there is no
      # persistent account to own the file. Decrypts to a YAML fragment:
      #   ntfy:
      #     notification:
      #       topic: <topic>
      ntfyAlertmanager.file = "${self}/secrets/ntfy/alertmanager.age";
    };

    # ---------------------------------------------------------------- Prometheus

    services.prometheus = {
      enable = true;

      # Loopback, not the tailnet address the previous version of this stack
      # used. Grafana is the only thing that queries this, and it runs here —
      # putting the TSDB on the tailnet exposed every metric from every host to
      # every device on it in exchange for nothing. Ad-hoc PromQL goes through
      # Grafana's Explore tab; an SSH tunnel covers the web UI when the
      # expression browser is genuinely wanted.
      listenAddress = "127.0.0.1";
      port = ports.prometheus.port;

      globalConfig = {
        # Explicit rather than inherited. The upstream default is 1m, which is
        # coarse enough to miss a CPU spike entirely, and 15s would double the
        # storage for a fleet this size with nothing asking for the resolution.
        scrape_interval = "30s";
        evaluation_interval = "30s";
      };

      # Both numbers are ceilings and whichever is reached first wins. The size
      # limit is the one that matters: it is what stops a runaway cardinality
      # bug from filling Argon's 320 GB disk, and the previous version of this
      # stack set neither, silently inheriting upstream's 15 days.
      retentionTime = "90d";
      extraFlags = [ "--storage.tsdb.retention.size=16GB" ];

      alertmanagers = [
        { static_configs = [ { targets = [ "127.0.0.1:${toString ports.alertmanager.port}" ]; } ]; }
      ];

      scrapeConfigs = [
        {
          # Hosts that are supposed to be up. `InstanceDown` covers this job and
          # only this job.
          job_name = "node";
          static_configs = mkTargets ports.nodeExporter.port tailnet.alwaysOn;
        }
        {
          # Laptops and desktops. Scraped identically — the dashboards do not
          # distinguish — but exempt from the down alert, because `up == 0` here
          # means someone closed a lid.
          job_name = "node-intermittent";
          static_configs = mkTargets ports.nodeExporter.port intermittentHosts;
        }
        {
          job_name = "smartctl";
          # SMART data changes on the order of hours, and each scrape wakes the
          # disks to ask. The exporter's own default poll is 60s; scraping it
          # faster than it refreshes just stores the same numbers repeatedly.
          scrape_interval = "5m";
          static_configs = mkTargets ports.smartctlExporter.port tailnet.physicalDisks;
        }
        {
          # Prometheus's own health. Cheap, and the only way to notice that
          # scrapes are being dropped or that the TSDB is unhappy — a monitoring
          # system that cannot see itself fails silently by construction.
          job_name = "prometheus";
          static_configs = [
            {
              targets = [ "127.0.0.1:${toString ports.prometheus.port}" ];
              labels.instance = "argon";
            }
          ];
        }
      ];
    };

    # -------------------------------------------------------------- Alertmanager

    services.prometheus.alertmanager = {
      enable = true;

      # The module's default is an empty string, which listens on every
      # interface. Only Prometheus talks to this, from this host.
      listenAddress = "127.0.0.1";
      port = ports.alertmanager.port;

      configuration = {
        route = {
          receiver = "ntfy";

          # Group by the alert and the host it is about, so a disk filling on
          # Helium and the same alert on Carbon arrive as two notifications
          # rather than one that reads as a single problem.
          group_by = [
            "alertname"
            "instance"
          ];

          group_wait = "30s";
          group_interval = "5m";

          # Twelve hours, not the four-hour default. Nothing here is on call:
          # a re-notification is a reminder, and a reminder every four hours for
          # a disk that will be dealt with at the weekend is how notifications
          # get muted.
          repeat_interval = "12h";
        };

        receivers = [
          {
            name = "ntfy";
            webhook_configs = [
              {
                url = "http://127.0.0.1:${toString ports.alertmanagerNtfy.port}/";

                # The resolved notification is half the value. An alert that
                # fires and never visibly clears trains you to treat the whole
                # stream as noise.
                send_resolved = true;
              }
            ];
          }
        ];
      };
    };

    # Turns Alertmanager's webhook JSON into an ntfy push with a real title,
    # a priority derived from firing/resolved, and an emoji tag. Alertmanager
    # can post a webhook but cannot template its body, so without a bridge the
    # phone receives raw JSON.
    services.prometheus.alertmanager-ntfy = {
      enable = true;

      settings = {
        http.addr = "127.0.0.1:${toString ports.alertmanagerNtfy.port}";
        ntfy.baseurl = cfg.ntfyBaseUrl;

        # Overridden by the credential file below, which is merged over this.
        # It cannot be omitted — the option has no default — and must not hold
        # the real value, which would put the topic in the world-readable store.
        ntfy.notification.topic = "";
      };

      # systemd reads this as root and exposes it through the credentials
      # directory, a per-unit tmpfs. The unit runs under DynamicUser, so this is
      # the only way in: there is no stable uid to chown an agenix file to.
      extraConfigFiles = [ config.age.secrets.ntfyAlertmanager.path ];
    };

    # ---------------------------------------------------------------------- Loki

    services.loki = {
      enable = true;

      configuration = {
        # No multi-tenancy. Any tailnet peer can push logs under any label,
        # which is the same trust boundary as everything else on the tailnet and
        # is accepted rather than overlooked — see the README.
        auth_enabled = false;

        server = {
          # The one component here that genuinely needs a tailnet-reachable
          # socket: four other hosts push to it. Everything else on Argon is on
          # loopback.
          http_listen_address = argonIP;
          http_listen_port = ports.loki.port;

          # Single binary, so the gRPC ring talks to itself. Port 0 asks the
          # kernel for a free one instead of holding 9095.
          grpc_listen_address = "127.0.0.1";
          grpc_listen_port = 0;

          log_level = "warn";
        };

        common = {
          path_prefix = "/var/lib/loki";
          replication_factor = 1;
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

        # Retention, which the previous version of this stack did not have at
        # all — and its absence is not visible for months. `retention_period`
        # alone does nothing: it marks chunks as expired, and only the compactor
        # deletes them, which it will not do unless `retention_enabled` is set.
        # Without both, Loki grows until the disk is full.
        compactor = {
          working_directory = "/var/lib/loki/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
          compaction_interval = "10m";
          retention_delete_delay = "2h";
        };

        limits_config = {
          retention_period = "30d";

          # Refuse anything older than a week. This is not retention — it is the
          # guard against a host with a badly wrong clock, or an Alloy that
          # buffered for days offline, injecting a backlog that lands in the
          # wrong place on every dashboard.
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";

          # Powers the log-volume histogram above the results in Grafana's
          # Explore view. Off by default, and its absence reads as a Grafana bug
          # rather than a Loki setting.
          volume_enabled = true;

          # A ceiling on how much damage one misbehaving host can do. Five
          # machines' journals are a rounding error against these; a service
          # stuck in a log loop is not.
          ingestion_rate_mb = 8;
          ingestion_burst_size_mb = 16;
          max_streams_per_user = 5000;
        };

        analytics.reporting_enabled = false;
      };
    };

    # Loki binds a tailnet address, so it loses the same cold-boot race the
    # exporters do — and its unit orders on `network-online.target`, which is
    # reached well before tailscaled has an address to hand out. Same treatment,
    # documented at length in this directory's default.nix.
    systemd.services.loki = {
      after = [ "tailscaled.service" ];
      unitConfig.StartLimitIntervalSec = 0;
      serviceConfig.RestartSec = 5;
    };

    # ------------------------------------------------------------------- Grafana

    services.grafana = {
      enable = true;

      settings = {
        server = {
          # Caddy is the only client. The vhost that fronts this is bound to a
          # userspace Tailscale node of its own — see hosts/argon/proxy.nix.
          http_addr = "127.0.0.1";
          http_port = ports.grafana.port;
          domain = ports.grafana.domain;
          root_url = "https://${ports.grafana.domain}/";
        };

        security = {
          # Declared, not seeded. Grafana's default is admin/admin with a
          # first-login prompt, which leaves the real password living only in
          # the mutable SQLite database — undeclared state that no rebuild can
          # reproduce and that this config would silently depend on forever.
          # `$__file{}` is Grafana's own indirection, so the value is read at
          # startup and never appears in the generated ini in the store.
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
          # Without this, a provisioned datasource that is later renamed or
          # removed here is left behind in the database forever.
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
              url = "http://127.0.0.1:${toString ports.prometheus.port}";
              isDefault = true;
              jsonData.timeInterval = "30s";
            }
            {
              name = "Loki";
              uid = lokiUID;
              type = "loki";
              access = "proxy";
              url = "http://${argonIP}:${toString ports.loki.port}";
            }
          ];
        };

        dashboards.settings.providers = [
          {
            name = "default";
            orgId = 1;
            type = "file";
            updateIntervalSeconds = 30;

            # Both of these make the store the source of truth. Without
            # `allowUiUpdates = false` an edit in the browser wins until the
            # next restart and then vanishes without warning; without
            # `disableDeletion` a dashboard deleted from this config stays in
            # the database. Editing a dashboard means editing dashboards.nix.
            allowUiUpdates = false;
            disableDeletion = true;

            options.path = dashboardDir;
          }
        ];
      };
    };
  };
}
