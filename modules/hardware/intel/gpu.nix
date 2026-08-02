{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHardware.intel.gpu.enable = lib.mkEnableOption "Intel GPU configuration.";

  config = lib.mkIf config.myHardware.intel.gpu.enable {
    hardware.graphics = {
      enable = true;
      extraPackages = [ pkgs.intel-media-driver ];
    };
  };
}
