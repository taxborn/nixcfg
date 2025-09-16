{ ... }:

{
  imports = [
    ../common
    ./caddy.nix

    ./hardware-configuration.nix
    ./disks.nix
  ];

  boot.loader.grub = {
    # no need to set devices, disko will add all devices that have a EF02 partition to the list already
    # devices = [ ];
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  users.users.root.openssh.authorizedKeys.keys = [
    # Temp for now, don't want this in root forever.
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOf8rn+JzRmVc6/4xKOJ4MrmId4xxpYPEgvbCrK18U+N yubikey"
  ];

  services.tailscale.enable = true;
  # https://github.com/NixOS/nixpkgs/issues/180175
  systemd.services.NetworkManager-wait-online.enable = false;
  systemd.services.tailscaled.after = [ "systemd-networkd-wait-online.service" ];

  networking.hostName = "carbon";
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ]; # might already be allowed? just to be safe.

  system.stateVersion = "25.05";
}
