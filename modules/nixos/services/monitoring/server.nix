{
  config,
  lib,
  self,
  ...
}:
let
  networkMap = config.mySnippets.mischief-town.networkMap;
  argonIP = networkMap.tailscaleIPs.argon;
  tailscaleDomain = "grafana.${config.mySnippets.tailnet.name}";
in
{
  options.myNixOS.services.monitoring.server.enable = lib.mkEnableOption "central monitoring server (Grafana + Prometheus + Loki)";

  config = lib.mkIf config.myNixOS.services.monitoring.server.enable {
    age.secrets.grafanaSecretKey = {
      file = "${self.inputs.secrets}/grafana/secretKey.age";
      owner = "grafana";
    };

    services.grafana = {
      enable = true;
      settings = {
        server = {
          http_addr = "127.0.0.1";
          http_port = networkMap.grafana.port;
          domain = tailscaleDomain;
        };
        security.secret_key = "$__file{${config.age.secrets.grafanaSecretKey.path}}";
      };
      provision.datasources.settings.datasources = [
        {
          name = "Prometheus";
          type = "prometheus";
          url = "http://${argonIP}:${toString networkMap.prometheus.port}";
          isDefault = true;
        }
        {
          name = "Loki";
          type = "loki";
          url = "http://${argonIP}:${toString networkMap.loki.port}";
        }
      ];
    };

    services.prometheus = {
      enable = true;
      listenAddress = argonIP;
      port = networkMap.prometheus.port;
      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = lib.mapAttrsToList (name: ip: {
            targets = [ "${ip}:${toString networkMap.nodeExporter.port}" ];
            labels.instance = name;
          }) networkMap.tailscaleIPs;
        }
      ];
    };

    services.loki = {
      enable = true;
      configuration = {
        auth_enabled = false;
        server = {
          http_listen_address = argonIP;
          http_listen_port = networkMap.loki.port;
          grpc_listen_port = 0;
        };
        ingester = {
          lifecycler = {
            address = "127.0.0.1";
            ring = {
              kvstore.store = "inmemory";
              replication_factor = 1;
            };
            final_sleep = "0s";
          };
          chunk_idle_period = "5m";
          chunk_retain_period = "30s";
        };
        schema_config.configs = [
          {
            from = "2020-01-01";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
        storage_config = {
          tsdb_shipper = {
            active_index_directory = "/var/lib/loki/tsdb-index";
            cache_location = "/var/lib/loki/tsdb-cache";
          };
          filesystem.directory = "/var/lib/loki/chunks";
        };
        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };
        compactor.working_directory = "/var/lib/loki/compactor";
      };
    };
  };
}
