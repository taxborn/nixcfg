{ modulesPath, ... }:

{
  imports = [
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
      backups.client = {
        enable = true;
        notify.enable = true;
      };
      braxton-is.enable = true;
      tangled.spindle.enable = true;
      # For friends, so it is reachable without the tailnet. The world lives in
      # the module's default, /var/lib/minecraft/mavs-updated.
      minecraft.servers.mavs-updated.openFirewall = true;
    };
  };

  myHardware = {
    profiles.ovh = {
      enable = true;
      ipv6 = {
        enable = true;
        address = "2604:2dc0:202:300::236a";
        gateway = "2604:2dc0:202:300::1";
      };
    };
  };
}
