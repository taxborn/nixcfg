{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.promtail;
in
{
  options.myNixOS.services.promtail = {
    enable = lib.mkEnableOption "promtail log shipper";

    lokiUrl = lib.mkOption {
      type = lib.types.str;
      description = "URL of the loki instance to ship logs to.";
      example = "http://localhost:3100";
    };
  };

  config = lib.mkIf cfg.enable {
    services.promtail = {
      enable = true;

      configuration = {
        server = {
          http_listen_port = 9080;
          grpc_listen_port = 0;
        };

        clients = [
          {
            url = "${cfg.lokiUrl}/loki/api/v1/push";
          }
        ];

        positions.filename = "/tmp/positions.yaml";

        scrape_configs = [
          {
            job_name = "journal";

            journal = {
              max_age = "12h";
              labels = {
                job = "systemd-journal";
                host = config.networking.hostName;
              };
            };

            relabel_configs = [
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "unit";
              }
            ];
          }
        ];
      };
    };
  };
}
