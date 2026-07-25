{ modulesPath, self, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-ovh
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = "carbon";
  system.stateVersion = "25.11";

  myNixOS.base.enable = true;
  myNixOS.profiles.btrfs.enable = true;

  myHardware = {
    intel.cpu.enable = true;
    profiles.ovh.enable = true;
  };
}
