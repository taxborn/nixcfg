{
  config,
  lib,
  self,
  ...
}:
{
  options.myNixOS.services.grafana = {
    enable = lib.mkEnableOption "grafana monitoring dashboard";

    prometheusTargets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Prometheus node_exporter scrape targets (host:port).";
    };
  };

  config = lib.mkIf config.myNixOS.services.grafana.enable {
    age.secrets.grafanaEnv = {
      file = "${self.inputs.secrets}/grafana.age";
      owner = "grafana";
    };

    systemd.services.grafana.serviceConfig.EnvironmentFile = config.age.secrets.grafanaEnv.path;

    services.grafana = {
      enable = true;

      settings.security = {
        admin_password = "$__env{GF_SECURITY_ADMIN_PASSWORD}";
        secret_key = "$__env{GF_SECURITY_SECRET_KEY}";
      };

      settings.server = {
        http_addr = "0.0.0.0";
        http_port = config.mySnippets.mischief-town.networkMap.grafana.port;
        domain = config.mySnippets.mischief-town.networkMap.grafana.vHost;
        root_url = "https://${config.mySnippets.mischief-town.networkMap.grafana.vHost}";
      };

      provision = {
        enable = true;
        datasources.settings.datasources = [
          {
            name = "Prometheus";
            type = "prometheus";
            url = "http://localhost:${toString config.mySnippets.mischief-town.networkMap.prometheus.port}";
            isDefault = true;
          }
          {
            name = "Loki";
            type = "loki";
            url = "http://localhost:${toString config.mySnippets.mischief-town.networkMap.loki.port}";
          }
        ];
      };
    };

    services.prometheus = {
      enable = true;
      port = config.mySnippets.mischief-town.networkMap.prometheus.port;

      scrapeConfigs = [
        {
          job_name = "node";
          static_configs = [
            {
              targets = config.myNixOS.services.grafana.prometheusTargets;
            }
          ];
        }
      ];
    };
  };
}
