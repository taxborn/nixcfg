{ modulesPath, ... }:

{
  imports = [
    ../../modules/nixos/services/atuin.nix
    ../../modules/nixos/services/glance.nix
    ../../modules/nixos/services/minecraft.nix
    ../../modules/nixos/services/ntfy.nix
    ../../modules/nixos/services/piper.nix
    ../../modules/nixos/services/tangled/knot.nix
    ../../modules/nixos/services/tranquil-pds.nix
    ../../modules/nixos/services/vaultwarden.nix
    ../../modules/nixos/ovh.nix
    ../../modules/nixos/server.nix
    ./disko.nix
    (modulesPath + "/profiles/qemu-guest.nix")
    ./proxy.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "argon";
  system.stateVersion = "25.11";

  myNixOS = {
    services = {
      backups.client = {
        enable = true;
        notify.enable = true;
      };
      # For friends, so it is reachable without the tailnet. The world lives in
      # the module's default, /var/lib/minecraft/mnb.
      minecraft.servers.mnb.openFirewall = true;
    };
  };

  myHardware.profiles.ovh.ipv6 = {
    # OVH gives this instance a second NIC for IPv6; ens3 keeps IPv4.
    interface = "ens4";
    address = "2604:2dc0:101:200::2cc6";
    gateway = "2604:2dc0:101:200::1";
    ipv4Method = "disabled";
  };
}
