{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myNixOS.programs.lanzaboote.enable = lib.mkEnableOption "secure boot with lanzaboote";

  config = lib.mkIf config.myNixOS.programs.lanzaboote.enable {
    boot = {
      initrd.systemd.enable = lib.mkDefault true;

      loader = {
        efi.canTouchEfiVariables = lib.mkDefault true;

        systemd-boot = {
          enable = lib.mkForce false;
          editor = lib.mkDefault false;
        };
      };

      lanzaboote = {
        enable = true;
        configurationLimit = lib.mkDefault 10;
        pkiBundle = lib.mkDefault "/var/lib/sbctl";
        autoGenerateKeys.enable = lib.mkDefault true;
        autoEnrollKeys = {
          enable = lib.mkDefault true;
          autoReboot = lib.mkDefault true;
          includeMicrosoftKeys = lib.mkDefault true;
        };
      };
    };

    environment.systemPackages = [ pkgs.sbctl ];
  };
}
