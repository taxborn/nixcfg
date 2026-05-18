{
  self,
  ...
}:
{
  imports = [
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.luks-btrfs-tungsten
  ];

  networking.hostName = "tungsten";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  myNixOS = {
    base.enable = true;
    desktop.hyprland = {
      enable = true;
      laptopMonitor = "eDP-1,3456x2160@60,0x0,2";
    };
    profiles = {
      btrfs.enable = true;
      graphical-boot.enable = true;
      swap.enable = true;
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
        outputScale = 2;
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
        "thunderbolt"
        "nvme"
        "usb_storage"
        "sd_mod"
        "rtsx_pci_sdmmc"
        "raid1"
        "md_mod"
      ];
    };
  };

  myHardware = {
    intel.cpu.enable = true;
    nvidia.gpu.enable = true;
    profiles.laptop.enable = true;
  };

  hardware.nvidia.prime = {
    nvidiaBusId = "PCI:1:0:0";
    intelBusId = "PCI:0:2:0";
  };
}
