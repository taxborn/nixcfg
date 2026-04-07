{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.fluent-bit;
in
{
  options.myNixOS.services.fluent-bit = {
    enable = lib.mkEnableOption "fluent-bit log shipper";

    lokiHost = lib.mkOption {
      type = lib.types.str;
      description = "Hostname or IP of the Loki instance.";
      example = "localhost";
    };

    lokiPort = lib.mkOption {
      type = lib.types.port;
      description = "Port of the Loki instance.";
      default = 3100;
    };
  };

  config = lib.mkIf cfg.enable {
    services.fluent-bit = {
      enable = true;

      settings = {
        service = {
          flush = 5;
          log_level = "warn";
        };

        pipeline = {
          inputs = [
            {
              name = "systemd";
              tag = "journal.*";
              strip_underscores = "on";
            }
          ];

          outputs = [
            {
              name = "loki";
              match = "journal.*";
              host = cfg.lokiHost;
              port = cfg.lokiPort;
              labels = "job=systemd-journal,host=${config.networking.hostName}";
              label_keys = "$SYSTEMD_UNIT";
            }
          ];
        };
      };
    };
  };
}
