{
  lib,
  pkgs,
  ...
}:
{
  boot = {
    loader = {
      efi.canTouchEfiVariables = lib.mkDefault true;

      systemd-boot = {
        enable = lib.mkForce false;

        # The boot editor would let anyone at the keyboard bypass Secure Boot.
        editor = lib.mkDefault false;
      };
    };

    lanzaboote = {
      enable = true;
      configurationLimit = lib.mkDefault 10;

      bootCounting.initialTries = lib.mkDefault 3;
      pkiBundle = lib.mkDefault "/var/lib/sbctl";
      autoGenerateKeys.enable = lib.mkDefault true;
      autoEnrollKeys = {
        enable = lib.mkDefault true;
        autoReboot = lib.mkDefault true;
        # GPU option ROMs are Microsoft-signed. Without these keys the card can stay dark.
        includeMicrosoftKeys = lib.mkDefault true;
      };
    };
  };

  environment.systemPackages = [ pkgs.sbctl ];
}
