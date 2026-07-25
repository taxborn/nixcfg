{ modulesPath, self, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-ovh
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = "argon";
  system.stateVersion = "25.11";

  myNixOS.profiles.server.enable = true;

  myHardware = {
    intel.cpu.enable = true;
    profiles.ovh.enable = true;
  };
}
