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
    age.secrets.grafanaAdminPassword = {
      file = "${self.inputs.secrets}/grafana.age";
      owner = "grafana";
    };

    systemd.services.grafana.serviceConfig.EnvironmentFile = config.age.secrets.grafanaAdminPassword.path;

    services.grafana = {
      enable = true;

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
            url = "http://localhost:9090";
            isDefault = true;
          }
        ];
      };
    };

    services.prometheus = {
      enable = true;
      port = 9090;

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
