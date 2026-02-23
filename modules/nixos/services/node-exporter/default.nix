{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.node-exporter.enable = lib.mkEnableOption "prometheus node exporter";

  config = lib.mkIf config.myNixOS.services.node-exporter.enable {
    services.prometheus.exporters.node = {
      enable = true;
      port = 9100;
      enabledCollectors = [ "systemd" ];
    };
  };
}
