{ modulesPath, self, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-ovh
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  networking.hostName = "carbon";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.server.enable = true;
    services.backups.client.enable = true;
  };

  myHardware = {
    intel.cpu.enable = true;
    profiles.ovh.enable = true;
  };
}
