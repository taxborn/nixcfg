{ self, ... }:

{
  imports = [
    self.diskoConfigurations.btrfs-helium
    ./external-hdd.nix
    ./proxy.nix
  ];

  networking.hostName = "helium";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.server.enable = true;
    programs.systemd-boot.enable = true;
    services = {
      paperless.enable = true;

      backups = {
        client = {
          enable = true;

          # Paperless keeps everything but the document files in postgres, and
          # borg walking a live cluster archives a torn set of pages. The dump
          # is the difference between a backup of this host and a copy of it.
          postgresqlDumpAll = true;
        };
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

    loader.timeout = 0;
  };
}
