{ modulesPath, ... }:

{
  imports = [
    ../../modules/nixos/services/braxton-is.nix
    ../../modules/nixos/services/minecraft.nix
    ../../modules/nixos/services/tangled/spindle.nix
    ../../modules/nixos/ovh.nix
    ../../modules/nixos/server.nix
    ./disko.nix
    ./proxy.nix
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "carbon";
  system.stateVersion = "25.11";

  myNixOS = {
    services = {
      # For friends, so it is reachable without the tailnet. The world lives in
      # the module's default, /var/lib/minecraft/mavs-updated.
      minecraft.servers.mavs-updated.openFirewall = true;
    };
  };

  myHardware.profiles.ovh.ipv6 = {
    address = "2604:2dc0:202:300::236a";
    gateway = "2604:2dc0:202:300::1";
  };
}
