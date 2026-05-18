{
  config,
  lib,
  pkgs,
  self,
  ...
}:
{
  options.myNixOS.base = {
    enable = lib.mkEnableOption "base system configuration";
  };

  config = lib.mkIf config.myNixOS.base.enable {
    environment = {
      etc."nixos".source = self;

      systemPackages = with pkgs; [
        self.inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
        age-plugin-yubikey
        btop
        just
        wget
      ];
    };

    hardware.enableRedistributableFirmware = lib.mkDefault true;

    programs.dconf.enable = true;

    myNixOS = {
      profiles.swap.enable = true;
      services.tailscale.enable = true;
    };

    networking.networkmanager.enable = true;

    services.fstrim.enable = true;

    # Bound persistent journal so boot/log-shippers don't replay months of
    # history and so disk usage stays predictable. ForwardToWall off to
    # skip a wall(1) write per emergency-level line.
    services.journald.extraConfig = ''
      SystemMaxUse=500M
      SystemKeepFree=1G
      MaxRetentionSec=2week
      ForwardToWall=no
    '';

    system.configurationRevision = self.rev or self.dirtyRev or null;

    i18n = {
      defaultLocale = lib.mkDefault "en_US.UTF-8";

      extraLocaleSettings = {
        LC_ADDRESS = config.i18n.defaultLocale;
        LC_IDENTIFICATION = config.i18n.defaultLocale;
        LC_MEASUREMENT = config.i18n.defaultLocale;
        LC_MONETARY = config.i18n.defaultLocale;
        LC_NAME = config.i18n.defaultLocale;
        LC_NUMERIC = config.i18n.defaultLocale;
        LC_PAPER = config.i18n.defaultLocale;
        LC_TELEPHONE = config.i18n.defaultLocale;
        LC_TIME = config.i18n.defaultLocale;
      };
    };
  };
}
