{ self, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-luks-raid1-uranium
  ];

  networking.hostName = "uranium";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.workstation.enable = true;
    programs.systemd-boot.enable = true;
  };

  # Root is a two-disk mdraid RAID1 (see the disko config); the raid modules
  # must be available in the initrd to assemble it before LUKS unlock.
  boot = {
    swraid.mdadmConf = "MAILADDR root";
    initrd.availableKernelModules = [
      "ahci"
      "usbhid"
      "raid1"
      "md_mod"
    ];
  };

  myHardware = {
    amd.gpu.enable = true;
    intel.cpu.enable = true;
  };
}
