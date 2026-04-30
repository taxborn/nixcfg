{
  config,
  lib,
  ...
}:
{
  options.myNixOS.profiles.workstation = {
    enable = lib.mkEnableOption "workstation desktop bundle (hyprland, sddm, lanzaboote, yubikey, luks fido2)";
  };

  config = lib.mkIf config.myNixOS.profiles.workstation.enable {
    myNixOS = {
      base.enable = true;
      desktop = {
        enable = true;
        hyprland.enable = true;
      };
      profiles = {
        btrfs.enable = true;
        impermanence.enable = true;
      };
      programs = {
        lanzaboote.enable = true;
        nix.enable = true;
        yubikey.enable = true;
      };
      services = {
        backups.client = {
          enable = true;
          enableRsyncRepo = true;
          enableHeliumRepo = true;
          desktopExcludes = true;
        };
        sddm.enable = true;
        tailscale.enable = true;
      };
    };

    fileSystems."/home".neededForBoot = true;

    boot.swraid.mdadmConf = "MAILADDR root";

    boot.initrd.luks = {
      devices."cryptroot".crypttabExtraOpts = [
        "fido2-device=auto"
        "token-timeout=30"
      ];
      fido2Support = false;
    };
  };
}
