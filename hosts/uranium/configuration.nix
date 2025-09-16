{
  pkgs,
  ...
}:

{
  imports = [
    ../common
    ../common/hyprland.nix

    ./hardware-configuration.nix
    ./disks.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    plymouth.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  extraServices = {
    virtualisation.enable = true;
    secure-boot.enable = true;
  };

  environment.systemPackages = with pkgs; [
    brightnessctl
    pavucontrol
  ];

  networking.hostName = "uranium";
  time.timeZone = "America/Chicago";

  system.stateVersion = "25.05";
}
