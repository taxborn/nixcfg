{ pkgs, self, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-helium
    ./external-hdd.nix
  ];

  networking.hostName = "helium";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.server.enable = true;
    programs.systemd-boot.enable = true;

    services.tailscale.enableSSH = false;
    services.backups = {
      client.enable = true;
      server = {
        enable = true;
        authorizedKeys = {
          argon = builtins.readFile "${self}/secrets/borg/argon/ssh_key.pub";
          carbon = builtins.readFile "${self}/secrets/borg/carbon/ssh_key.pub";
          tungsten = builtins.readFile "${self}/secrets/borg/tungsten/ssh_key.pub";
          uranium = builtins.readFile "${self}/secrets/borg/uranium/ssh_key.pub";
        };
      };
    };
  };

  myHardware.intel.cpu.enable = true;

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];

    # The countdown was 5s of a 42s boot, spent on a menu nothing reads. Holding
    # space through firmware still brings it up when a generation needs picking,
    # so this costs nothing but the wait. Hosts on the graphical-boot profile
    # already run at 0; this one is not one of them.
    loader.timeout = 1;
  };
}
