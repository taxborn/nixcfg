{ self, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-luks-raid1-tungsten
  ];

  networking.hostName = "tungsten";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.workstation.enable = true;
    programs.lanzaboote.enable = true;
    services.backups.client = {
      enable = true;
      desktopExcludes = true;
    };
  };

  boot.initrd.availableKernelModules = [
    "thunderbolt"
    "rtsx_pci_sdmmc"
  ];

  myHardware = {
    nvidia.gpu.enable = true;
    intel.cpu.enable = true;
  };
}
