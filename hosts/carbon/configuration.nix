{
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ../common
    ./caddy.nix

    ./hardware-configuration.nix
    ./disks.nix
    ./backup.nix
  ];

  networking.hostName = "carbon";
  time.timeZone = "America/Chicago";

  environment.systemPackages = with pkgs; [
    jdk21_headless

    inputs.agenix.packages."${system}".default
  ];
  networking.firewall.allowedTCPPorts = [
    25565
    25566
  ];

  environment.pathsToLink = [
    "/share/applications"
    "/share/xdg-desktop-portal"
  ];

  system.stateVersion = "25.05";
}
