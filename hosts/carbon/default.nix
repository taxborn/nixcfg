{ modulesPath, ... }:

{
  imports = [
    ./disko.nix
    (modulesPath + "/profiles/qemu-guest.nix")
    ./proxy.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "carbon";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.server.enable = true;
    services = {
      backups.client.enable = true;
      braxton-is.enable = true;
    };
  };

  myHardware = {
    intel.cpu.enable = true;
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
