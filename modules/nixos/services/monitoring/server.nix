{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.monitoring.server;

  tailnet = config.mySnippets.tailnet;
  monitoring = config.mySnippets.monitoring;
  inherit (monitoring) ports;
  grafana = config.mySnippets.biscuits-at.networkMap.grafana;

  hostname = config.networking.hostName;
  serverIP = config.myNixOS.services.tailscale.address;

  # Where the bridge's credential file is generated, see `alertmanager-ntfy-auth`.
  ntfyAuthFile = "/run/alertmanager-ntfy-auth/auth.yml";

  # The roster, partitioned. Every host on the tailnet is scraped. The split
  # only decides which job a host lands in, and the job is what the down alert
  # keys off. See `mySnippets.monitoring.alwaysOn`.
  allHosts = lib.attrNames tailnet.tailscaleIPs;
  intermittentHosts = lib.subtractLists monitoring.alwaysOn allHosts;

  # One `static_configs` entry per host, each carrying its own `instance` label
  # so graphs and alerts read `helium` rather than `100.64.1.0:9100`. Safe as a
  # per-target label rather than a relabel rule only because each entry has
  # exactly one target. Two targets sharing one entry would collapse to the
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
        # dropped instead of producing a target with an empty address. The
        # assertions below turn that into a build failure anyway.
        lib.filterAttrs (n: _: lib.elem n hosts) tailnet.tailscaleIPs
      );

  dashboardDir = "/etc/grafana-dashboards";

  # Datasource UIDs are pinned rather than left for Grafana to generate, because
  # provisioned dashboards have to name them at build time. Otherwise they carry
  # a datasource picker variable with no default, which renders an empty screen
  # until someone chooses from a dropdown and stores that choice per-user in the
  # mutable database.
  promUID = "prometheus";
  lokiUID = "loki";
in
{
  options.myNixOS.services.monitoring.server = {
    enable = lib.mkEnableOption "monitoring server (Prometheus, Loki, Grafana, Alertmanager)";

    ntfyTopic = lib.mkOption {
      type = lib.types.str;
      default = "alerts";
      description = ''
        ntfy topic alerts are published to, on the instance `networkMap.ntfy`
        points at. That server denies everything by default, so the access rules
        in `secrets/ntfy.age` have to grant the write-only publisher token
        write access to this topic, or every alert is rejected with a 403 that
        only shows up in the bridge's journal.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.services.tailscale.enable;
        message = "myNixOS.services.monitoring.server binds Loki to a tailnet address, but services.tailscale.enable is false.";
      }
      {
        assertion = hostname == monitoring.server && serverIP != null;
        message = ''
          myNixOS.services.monitoring.server is enabled on ${hostname}, but
          mySnippets.monitoring.server names ${monitoring.server}. Every Alloy
          pushes to the host in the snippet, so the two have to be the same
          machine, and it needs a tailnet address to bind Loki to.
        '';
      }
      {
        assertion = lib.all (h: lib.elem h allHosts) (monitoring.alwaysOn ++ monitoring.physicalDisks);
        message = "mySnippets.monitoring.alwaysOn and physicalDisks may only name hosts in mySnippets.tailnet.tailscaleIPs.";
      }
    ];

    age.secrets = {
      # Grafana reads this itself, at startup, through the `$__file{}`
      # indirection below, so unlike a systemd credential the process needs to
      # open it directly.
      grafanaAdminPassword = {
        file = "${self}/secrets/grafana/admin-password.age";
        owner = "grafana";
        mode = "0400";
      };

      # Signs Grafana's cookies and encrypts credentials it stores. nixpkgs 26.05
      # removed the shared default key, so Grafana refuses to evaluate without
      # one. Nothing stored here is a secret yet, so rotating it costs sessions.
      grafanaSecretKey = {
        file = "${self}/secrets/grafana/secret-key.age";
        owner = "grafana";
        mode = "0400";
      };

      # The write-only publisher token every backup client already uses. It can
      # publish to the topics the server's ACL names and read nothing, so reusing
      # it adds no new credential. Read by root in `alertmanager-ntfy-auth`.
      ntfyToken = {
        file = "${self}/secrets/ntfy/token.age";
        mode = "0400";
      };
    };

    # ---------------------------------------------------------------- Prometheus

    services.prometheus = {
      enable = true;

      # Loopback. Grafana is the only thing that queries this and it runs here.
      # Putting the TSDB on the tailnet would expose every metric from every
      # host to every device on it for nothing. Ad-hoc PromQL goes through
      # Grafana's Explore tab, and an SSH tunnel covers the web UI.
      listenAddress = "127.0.0.1";
      port = ports.prometheus;

      globalConfig = {
        # Explicit rather than inherited. The upstream default is 1m, which is
        # coarse enough to miss a CPU spike entirely, and 15s would double the
        # storage for a fleet this size with nothing asking for the resolution.
        scrape_interval = "30s";
        evaluation_interval = "30s";
      };

      # Both numbers are ceilings and whichever is reached first wins. The size
      # limit is the one that matters: it stops a runaway cardinality bug from
      # filling the disk, where the upstream default is 15 days and no size cap.
      retentionTime = "90d";
      extraFlags = [ "--storage.tsdb.retention.size=16GB" ];

      alertmanagers = [
        { static_configs = [ { targets = [ "127.0.0.1:${toString ports.alertmanager}" ]; } ]; }
      ];

      scrapeConfigs = [
        {
          # Hosts that are supposed to be up. `InstanceDown` covers this job and
          # only this job.
          job_name = "node";
          static_configs = mkTargets ports.nodeExporter monitoring.alwaysOn;
        }
        {
          # Laptops and desktops. Scraped identically, since the dashboards do
          # not distinguish, but exempt from the down alert because `up == 0`
          # here means someone closed a lid.
          job_name = "node-intermittent";
          static_configs = mkTargets ports.nodeExporter intermittentHosts;
        }
        {
          job_name = "smartctl";
          # SMART data changes on the order of hours, and each scrape wakes the
          # disks to ask. The exporter's own poll is 60s, so scraping faster
          # just stores the same numbers repeatedly.
          scrape_interval = "5m";
          static_configs = mkTargets ports.smartctlExporter monitoring.physicalDisks;
        }
        {
          # Prometheus's own health. Cheap, and the only way to notice that
          # scrapes are being dropped or the TSDB is unhappy. A monitoring
          # system that cannot see itself fails silently by construction.
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

    # -------------------------------------------------------------- Alertmanager

    services.prometheus.alertmanager = {
      enable = true;

      # The module's default is an empty string, which listens on every
      # interface. Only Prometheus talks to this, from this host.
      listenAddress = "127.0.0.1";
      port = ports.alertmanager;

      # Clustering is on by default and binds 9094 on every interface, to gossip
      # with peers that do not exist. An empty address turns it off.
      extraFlags = [ "--cluster.listen-address=" ];

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

          # Twelve hours, not the four-hour default. Nothing here is on call, so
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
                # `/hook`, not `/`. The bridge serves the webhook on that one
                # path and answers 404 everywhere else. Alertmanager records a
                # delivery error in its own log and moves on, so the alert fires,
                # resolves, and never reaches a phone.
                url = "http://127.0.0.1:${toString ports.alertmanagerNtfy}/hook";

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

    # Turns Alertmanager's webhook JSON into an ntfy push with a real title, a
    # priority derived from firing or resolved, and a coloured tag. Alertmanager
    # can post a webhook but cannot template its body, so without a bridge the
    # phone receives raw JSON.
    services.prometheus.alertmanager-ntfy = {
      enable = true;

      settings = {
        http.addr = "127.0.0.1:${toString ports.alertmanagerNtfy}";
        # The ntfy instance on Argon, read from the same entry its own module
        # and vhost use.
        ntfy.baseurl = "https://${config.mySnippets.biscuits-at.networkMap.ntfy.domain}";
        ntfy.notification.topic = cfg.ntfyTopic;
      };

      # The bridge wants its token as a YAML fragment, and the shared publisher
      # token is a bare string. systemd reads this file as root and hands it
      # over through the credentials directory, because the unit runs under
      # DynamicUser and has no stable uid to chown an agenix file to.
      extraConfigFiles = [ ntfyAuthFile ];
    };

    systemd.services = {
      # Renders the YAML fragment above from the bare token, into a root-only
      # tmpfs directory, so the token never reaches the Nix store. The bridge
      # cannot start without it, hence the ordering.
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

      # Loki binds a tailnet address, so it loses the same cold-boot race the
      # exporters do, and its unit orders on `network-online.target`, which is
      # reached well before tailscaled has an address to hand out.
      loki = config.myNixOS.services.tailscale.bindOrdering;
    };

    # ---------------------------------------------------------------------- Loki

    services.loki = {
      enable = true;

      configuration = {
        # No multi-tenancy. Any tailnet peer can push logs under any label,
        # which is the same trust boundary as everything else on the tailnet and
        # is accepted rather than overlooked. See the README.
        auth_enabled = false;

        server = {
          # The one component here that needs a tailnet-reachable socket, since
          # every other host pushes to it. Everything else is on loopback.
          http_listen_address = serverIP;
          http_listen_port = ports.loki;

          # Single binary, so the gRPC ring talks to itself, over loopback and
          # never the tailnet. The port is pinned rather than left at 0: the
          # kernel does hand out a free port, but the ring goes on advertising
          # the configured value, so every internal client dials 127.0.0.1:0.
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

        # `retention_period` alone does nothing. It marks chunks as expired and
        # only the compactor deletes them, which it will not do unless
        # `retention_enabled` is set. Without both, Loki grows until the disk is
        # full, and the absence is not visible for months.
        compactor = {
          working_directory = "/var/lib/loki/compactor";
          retention_enabled = true;
          delete_request_store = "filesystem";
          compaction_interval = "10m";
          retention_delete_delay = "2h";
        };

        limits_config = {
          retention_period = "30d";

          # Refuse anything older than a week. This is not retention. It guards
          # against a host with a badly wrong clock, or an Alloy that buffered
          # for days offline, injecting a backlog that lands in the wrong place
          # on every dashboard.
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";

          # Powers the log-volume histogram above the results in Grafana's
          # Explore view. Off by default, and its absence reads as a Grafana bug
          # rather than a Loki setting.
          volume_enabled = true;

          # A ceiling on how much damage one misbehaving host can do. Five
          # machines' journals are a rounding error against these, and a service
          # stuck in a log loop is not.
          ingestion_rate_mb = 8;
          ingestion_burst_size_mb = 16;
          max_streams_per_user = 5000;
        };

        analytics.reporting_enabled = false;
      };
    };

    # ------------------------------------------------------------------- Grafana

    services.grafana = {
      enable = true;

      settings = {
        server = {
          # Caddy is the only client, see hosts/helium/proxy.nix.
          http_addr = "127.0.0.1";
          http_port = grafana.port;
          inherit (grafana) domain;
          root_url = "https://${grafana.domain}/";
        };

        security = {
          # Declared, not seeded. Grafana's default is admin/admin with a
          # first-login prompt, which leaves the real password living only in
          # the mutable SQLite database: undeclared state no rebuild can
          # reproduce. `$__file{}` is Grafana's own indirection, so the value is
          # read at startup and never appears in the generated ini in the store.
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

            # Both make the store the source of truth. Without
            # `allowUiUpdates = false` an edit in the browser wins until the
            # next restart and then vanishes without warning. Without
            # `disableDeletion` a dashboard deleted from this config stays in
            # the database. Editing a dashboard means editing dashboards.nix.
            allowUiUpdates = false;
            disableDeletion = true;

            options.path = dashboardDir;
          }
        ];
      };
    };

    # Prometheus, Loki and Grafana all keep state under /var/lib, and none of
    # it belongs in an archive. A metrics store restored from last night is a
    # gap-free record of a machine that no longer exists, and Grafana holds
    # nothing that provisioning does not rebuild, but does hold a live SQLite
    # file that borg would copy torn. None of these paths overlaps borgmatic's
    # dump staging directory.
    myNixOS.services.backups.client.extraExcludes =
      lib.mkIf config.myNixOS.services.backups.client.enable
        [
          "/var/lib/prometheus2"
          "/var/lib/loki"
          "/var/lib/grafana"
        ];
  };
}
