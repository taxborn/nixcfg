{ ... }:

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

  system.stateVersion = "25.05";
}
