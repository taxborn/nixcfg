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

  users.users.root.openssh.authorizedKeys.keys = [
    # Temp for now, don't want this in root forever.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOf8rn+JzRmVc6/4xKOJ4MrmId4xxpYPEgvbCrK18U+N yubikey"
  ];

  # https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = false;
  systemd.services.tailscaled.after = [ "systemd-networkd-wait-online.service" ];

  environment.systemPackages = with pkgs; [
    jdk21_headless
    borgbackup
    ntfs3g
  ];

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ]; # might already be allowed? just to be safe.

  system.stateVersion = "25.05";
}
