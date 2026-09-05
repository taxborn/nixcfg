{
  config,
  lib,
  ...
}:
{
  options.myNixOS.profiles.bluetooth.enable = lib.mkEnableOption "bluetooth";

  config = lib.mkIf config.myNixOS.profiles.bluetooth.enable {
    hardware.bluetooth.enable = true;
  };
}
