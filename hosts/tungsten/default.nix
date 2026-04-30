{
  self,
  ...
}:
{
  imports = [
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.luks-btrfs-tungsten
    self.nixosModules.locale-en-us
  ];

  networking.hostName = "tungsten";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.workstation.enable = true;
    desktop.hyprland.laptopMonitor = "eDP-1,3456x2160@60,0x0,2";
    services.backups.client.extraExcludes = [
      # managed by Obsidian sync, no need to back up
      "/home/taxborn/documents/notes"
    ];
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

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
    "raid1"
    "md_mod"
  ];
}
