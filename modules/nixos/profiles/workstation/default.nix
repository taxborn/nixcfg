{
  config,
  lib,
  ...
}:
{
  options.myNixOS.profiles.workstation.enable = lib.mkEnableOption "workstation profile";

  config = lib.mkIf config.myNixOS.profiles.workstation.enable {
    myNixOS = {
      base.enable = true;
      desktop = {
        enable = true;
        hyprland.enable = true;
      };
      profiles = {
        btrfs.enable = true;
        graphical-boot.enable = true;
      };
      programs = {
        claude-desktop.enable = true;
        systemd-boot.enable = true;
        nix.enable = true;
        yubikey.enable = true;
      };
      services = {
        greetd.enable = true;
        openssh.enable = true;
      };
    };

    boot = {
      swraid.mdadmConf = "MAILADDR root";
      initrd = {
        luks = {
          devices."cryptroot" = {
            bypassWorkqueues = true;
            crypttabExtraOpts = [
              "fido2-device=auto"
              "token-timeout=30"
            ];
          };
          fido2Support = false;
        };
        availableKernelModules = [
          "xhci_pci"
          "nvme"
          "usb_storage"
          "sd_mod"
          "raid1"
          "md_mod"
        ];
      };
    };
  };
}
