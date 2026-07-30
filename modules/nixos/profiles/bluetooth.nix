{
  config,
  lib,
  ...
}:
{
  options.myNixOS.profiles.bluetooth.enable = lib.mkEnableOption "enable bluetooth";

  config = lib.mkIf config.myNixOS.profiles.bluetooth.enable {
    hardware.bluetooth.enable = true;
  };
}
