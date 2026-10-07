{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.profiles.bluetooth;
in
{
  options.myNixOS.profiles.bluetooth.enable = lib.mkEnableOption "bluetooth";

  config = lib.mkIf cfg.enable {
    hardware.bluetooth.enable = true;
  };
}
