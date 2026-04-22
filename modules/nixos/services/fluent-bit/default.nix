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
    # DynamicUser=true already set by upstream module; StateDirectory gives
    # fluent-bit a writable path at /var/lib/fluent-bit for its disk spool.
    systemd.services.fluent-bit.serviceConfig = {
      StateDirectory = "fluent-bit";
      StateDirectoryMode = "0700";
    };

    services.fluent-bit = {
      enable = true;

      settings = {
        service = {
          flush = 5;
          log_level = "warn";
          storage = {
            path = "/var/lib/fluent-bit/storage";
            sync = "normal";
            checksum = "off";
            backlog.mem_limit = "64M";
          };
        };

        pipeline = {
          inputs = [
            {
              name = "systemd";
              tag = "journal.*";
              strip_underscores = "on";
              # Only ship new journal entries. Prevents Loki from rejecting
              # historical records with "timestamp too old" and fluent-bit
              # piling the backlog into RAM forever.
              read_from_tail = "on";
              storage.type = "filesystem";
              mem_buf_limit = "32M";
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
              # Drop permanently-failing chunks instead of retrying forever.
              retry_limit = 5;
              storage.total_limit_size = "512M";
            }
          ];
        };
      };
    };
  };
}
