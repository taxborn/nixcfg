{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.smartctl-exporter = {
    enable = lib.mkEnableOption "smartctl prometheus exporter";

    devices = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Device paths to monitor (e.g. /dev/disk/by-id/...).";
    };
  };

  config = lib.mkIf config.myNixOS.services.smartctl-exporter.enable {
    services.prometheus.exporters.smartctl = {
      enable = true;
      port = config.mySnippets.mischief-town.networkMap.smartctlExporter.port;
      listenAddress = "127.0.0.1";
      devices = config.myNixOS.services.smartctl-exporter.devices;
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "smartctl";
        static_configs = [
          {
            targets = [ "localhost:${toString config.mySnippets.mischief-town.networkMap.smartctlExporter.port}" ];
          }
        ];
      }
    ];
  };
}
