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

  networking.hostName = "uranium";
  time.timeZone = "America/Chicago";

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  extraServices = {
    virtualisation.enable = true;
    secure-boot.enable = true;
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  environment.systemPackages = with pkgs; [
    pavucontrol
  ];

  system.stateVersion = "25.05";
}
