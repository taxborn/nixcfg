{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.programs.systemd-boot;
in
{
  options.myNixOS.programs.systemd-boot.enable = lib.mkEnableOption "systemd bootloader";

  config = lib.mkIf cfg.enable {
    boot = {
      loader = {
        efi.canTouchEfiVariables = lib.mkDefault true;

        systemd-boot = {
          enable = lib.mkDefault true;
          configurationLimit = lib.mkDefault 10;
        };
      };
    };
  };
}
