{ self, pkgs, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-luks-raid1-tungsten
  ];

  networking.hostName = "tungsten";
  system.stateVersion = "25.11";

  environment.systemPackages = [ pkgs.brightnessctl ];

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
    intel = {
      cpu.enable = true;
      gpu.enable = true;
    };
    profiles.laptop.enable = true;
  };

  hardware.nvidia.prime = {
    nvidiaBusId = "PCI:1:0:0";
    intelBusId = "PCI:0:2:0";
  };
}
