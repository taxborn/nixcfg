{ pkgs, self, ... }:

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

    services.tailscale.enableSSH = false;
    services.paperless.enable = true;

    # Note what this host already is before adding capacity here: it holds the
    # Paperless documents and it is the borg server every other host writes its
    # archives to. A job here shares a network stack with both, so it is worth
    # keeping the container isolation in the runner module intact — in
    # particular `container.network` and the absence of a `host` label.
    services.forgejo.runner.enable = true;
    services.backups = {
      client = {
        enable = true;

        # The live database is excluded in favour of this dump; see the option's
        # description for why copying a SQLite file out from under a running
        # service is not a backup. Documents themselves are ordinary files under
        # /var/lib/paperless/media and ride along in the default paths.
        sqliteDatabases.paperless = "/var/lib/paperless/db.sqlite3";

        # Rebuilt from the database and the documents on demand — the scheduler
        # runs `document_index reindex --if-needed` on every start, and after a
        # restore that is exactly the case it detects. Carrying it would put a
        # large, entirely derived, constantly rewritten tree in every archive.
        extraExcludes = [ "/var/lib/paperless/index" ];
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
