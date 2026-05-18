{
  self,
  ...
}:
{
  imports = [
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.luks-btrfs-uranium
  ];

  networking.hostName = "uranium";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  myNixOS = {
    base.enable = true;
    desktop.hyprland = {
      enable = true;
      monitors = [
        "DP-3,2560x1440@165,0x0,1"
        "HDMI-A-5,1920x1080@60,2560x320,1"
      ];
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
      greetd = {
        enable = true;
        primaryOutput = "DP-3";
      };
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
        "ahci"
        "nvme"
        "usbhid"
        "usb_storage"
        "sd_mod"
        "raid1"
        "md_mod"
      ];
    };
  };

  myHardware = {
    intel.cpu.enable = true;
    amd.gpu.enable = true;
  };
}
