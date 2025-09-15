{ pkgs, ... }:

{
  imports = [
    ../common/nix.nix
    ../common/ssh.nix
    ../common/users.nix

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

  services.caddy = {
    enable = true;
    virtualHosts."taxborn.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    virtualHosts."www.taxborn.com".extraConfig = ''
      respond "Hello, World!"
    '';
    virtualHosts."ticker.blue".extraConfig = ''
      redir https://www.ticker.blue{uri} permanent
    '';
    virtualHosts."www.ticker.blue".extraConfig = ''
      respond "Hello, World!"
    '';
  };

  networking.firewall.allowedTCPPorts = [
    80
    443
    22 # might already be allowed? just to be safe.
  ];
  networking.hostName = "carbon";
  time.timeZone = "America/Chicago";

  services.openssh.enable = true;

  system.stateVersion = "25.05";
}
