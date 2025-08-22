{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./disko.nix
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
  i18n.defaultLocale = "en_US.UTF-8";

  users.users.taxborn = {
    isNormalUser = true;
    initialHashedPassword = "$y$j9T$VyMfknbgYNTja6wNOlXnW.$YkQdA0gJh1VgkFmp185FbsXTvXsKM8/9J1isezUg.37"; # mkpasswd
    openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOf8rn+JzRmVc6/4xKOJ4MrmId4xxpYPEgvbCrK18U+N yubikey"
    ];
    extraGroups = [ "wheel" "networkmanager" ];
    packages = with pkgs; [ ];
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.taxborn = import ./home/taxborn.nix;

  services.openssh = {
    enable = true;
    settings = {
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };
  services.udev = {
    packages = [ pkgs.yubikey-personalization ];
  };
  services.pcscd.enable = true;
  services.libinput.enable = true;

  programs.gnupg.agent = {
    enable = true;
    enableSSHSupport = true;
  };

  programs.hyprland.enable = true;
  programs.firefox.enable = true; # TODO: Zen

  environment.systemPackages = with pkgs; [
    vim
    neovim
    wget
    git
    ghostty
  ];
  environment.variables.EDITOR = "neovim";

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "25.05";
}
