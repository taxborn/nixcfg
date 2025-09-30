{ pkgs, ... }:

{
  imports = [
    ../common
    ./caddy.nix

    ./hardware-configuration.nix
    ./disks.nix
    # ./backup.nix # TODO: Backup on helium
  ];

  networking.hostName = "helium-01";
  time.timeZone = "America/Chicago";

  # https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = false;
  systemd.services.tailscaled.after = [ "systemd-networkd-wait-online.service" ];

  environment.systemPackages = with pkgs; [
    jdk21_headless
    borgbackup
  ];

  system.stateVersion = "25.05";
}
