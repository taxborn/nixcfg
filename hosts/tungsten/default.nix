{ pkgs, ... }:

{
  imports = [
    ./intel-gpu.nix
    ./laptop.nix
    ./nvidia.nix
    ../../modules/nixos/workstation
    ./disko.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "tungsten";
  system.stateVersion = "25.11";

  environment.systemPackages = [ pkgs.brightnessctl ];

  homelab.backups.desktopExcludes = true;

  boot.initrd.availableKernelModules = [
    "thunderbolt"
    "rtsx_pci_sdmmc"
  ];

  # Bus IDs in NixOS' decimal `PCI:bus:device:function` form, taken from
  # `lspci`, which prints them in hex. They name the slots, so a different
  # board needs different values. The offload settings live in laptop.nix.
  hardware.nvidia.prime = {
    nvidiaBusId = "PCI:1:0:0";
    intelBusId = "PCI:0:2:0";
  };
}
