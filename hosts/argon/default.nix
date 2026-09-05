{ modulesPath, ... }:

{
  imports = [
    ./disko.nix
    (modulesPath + "/profiles/qemu-guest.nix")
    ./proxy.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "argon";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.server.enable = true;
    services = {
      backups.client.enable = true;
      forgejo.enable = true;
      glance.enable = true;
      piper.enable = true;
      tranquil-pds.enable = true;
      vaultwarden.enable = true;
    };
  };

  myHardware = {
    intel.cpu.enable = true;
    profiles.ovh = {
      enable = true;
      # OVH gives this instance a second NIC for IPv6; ens3 keeps IPv4.
      ipv6 = {
        enable = true;
        interface = "ens4";
        address = "2604:2dc0:101:200::2cc6";
        gateway = "2604:2dc0:101:200::1";
        ipv4Method = "disabled";
      };
    };
  };
}
