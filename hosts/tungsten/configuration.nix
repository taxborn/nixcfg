{ config, lib, pkgs, ... }:

{
  imports =
    [
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
  networking.networkmanager.enable = true;
  time.timeZone = "America/Chicago";

  services.libinput.enable = true;

  services.tailscale.enable = true;

  programs.hyprland.enable = true;
  programs.firefox.enable = true; # TODO: Zen

  environment.systemPackages = with pkgs; [
    vim
    neovim
    wget
    git
    tmux
    ghostty
    kitty
  ];
  environment.variables.EDITOR = "nvim";

  system.stateVersion = "25.05";
}
