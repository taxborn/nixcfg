{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    ../common

    ./hardware-configuration.nix
    ./disks.nix
  ];

  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    device = "nodev";
  };
  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "tungsten";
  time.timeZone = "America/Chicago";

  services.libinput.enable = true;
  programs.hyprland.enable = true;

  environment.systemPackages = with pkgs; [
    ghostty
    kitty
    nixfmt-rfc-style
  ];

  system.stateVersion = "25.05";
}
