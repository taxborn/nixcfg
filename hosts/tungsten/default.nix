{ self, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-luks-raid1-tungsten
  ];

  networking.hostName = "tungsten";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.workstation.enable = true;
    programs.lanzaboote.enable = true;

    # Scaffolded, not yet working: this needs `secrets/borg/tungsten/` to exist
    # and `keys/root_tungsten.pub` in `secrets/secrets.nix`, neither of which
    # can be produced before the host is installed and has a host key. Until
    # then activation reports a failed decrypt and borgmatic has no passphrase.
    # Steps 1-4 of the module README are the fix, in that order.
    #
    # No local repository, unlike uranium — the laptop has no companion drive,
    # so this is rsync.net and helium only.
    services.backups.client = {
      enable = true;
      desktopExcludes = true;
    };
  };

  # Root is a two-disk mdraid RAID1 (see the disko config); the raid modules
  # must be available in the initrd to assemble it before LUKS unlock. The
  # fallback ESP on nvme1 is populated by the disko module itself.
  boot = {
    swraid.mdadmConf = "MAILADDR root";
    initrd.availableKernelModules = [
      "thunderbolt"
      "rtsx_pci_sdmmc"
    ];
  };

  myHardware = {
    nvidia.gpu.enable = true;
    intel.cpu.enable = true;
  };
}
