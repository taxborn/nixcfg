{ pkgs, ... }:

{
  imports = [
    ../../modules/nixos/workstation
    ./disko.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "tungsten";
  system.stateVersion = "25.11";

  environment.systemPackages = [ pkgs.brightnessctl ];

  myNixOS = {
    services.backups.client = {
      enable = true;
      notify.enable = true;
      desktopExcludes = true;
    };
  };

  boot.initrd.availableKernelModules = [
    "thunderbolt"
    "rtsx_pci_sdmmc"
  ];

  myHardware = {
    nvidia.gpu.enable = true;
    intel.gpu.enable = true;
    profiles.laptop.enable = true;
  };

  # Bus IDs in NixOS' decimal `PCI:bus:device:function` form, taken from
  # `lspci`, which prints them in hex. They name the slots, so a different
  # board needs different values. The offload settings live in the laptop
  # profile.
  hardware.nvidia.prime = {
    nvidiaBusId = "PCI:1:0:0";
    intelBusId = "PCI:0:2:0";
  };
}
