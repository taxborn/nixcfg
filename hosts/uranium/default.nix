{
  self,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    self.diskoConfigurations.btrfs-luks-raid1-uranium
  ];

  networking.hostName = "uranium";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.workstation.enable = true;
    programs.lanzaboote.enable = true;

    # Proton prefixes hold every local save for a game that does not sync
    # through Steam Cloud, and they live on the games drive rather than the
    # mirror. Snapshots cover the case a nightly backup cannot — noticing a
    # corrupted save an hour after the fact — while borg covers the drive
    # itself dying. The ~280G of game installs surrounding this subvolume get
    # neither, which is the whole reason the split exists.
    profiles.btrfs.snapshotSubvolumes.compatdata = "/games/steamapps/compatdata";

    services.backups.client = {
      enable = true;

      # First workstation in the backup set, so the first host where /home is
      # mostly cache. See the option — without this the nightly run ships
      # browser and Electron caches and Steam's runtime to all three
      # repositories. The `.snapshots` directory under the compatdata subvolume
      # below is excluded on its own, by the btrfs profile.
      desktopExcludes = true;

      # The module's default, plus the Proton prefixes. Everything else on the
      # games drive is re-downloadable from Valve and stays out of the archive
      # deliberately — it would otherwise be ~280G of Marvel Rivals going to
      # rsync.net nightly.
      paths = [
        "/home"
        "/var/lib"
        "/etc"
        "/games/steamapps/compatdata"
      ];

      # A third repository alongside rsync.net and helium, on the 850 EVO. The
      # off-site copies are what survive the house burning down; this one is
      # what makes a restore an afternoon rather than a weekend, since ~50G off
      # local SATA beats dragging it back over the tailnet.
      repositories.local = {
        label = "local";
        path = "/mnt/backup/borg/uranium";
      };
    };
  };

  # Fresh btrfs subvolumes come out of mkfs owned by root, and /games/steamapps
  # exists only as a bare mountpoint for the compatdata subvolume beneath it.
  # Steam runs as taxborn, so without this it cannot create its library at all —
  # the drive would mount correctly and then be unusable.
  systemd.tmpfiles.rules = [
    "d /games 0755 taxborn users -"
    "d /games/steamapps 0755 taxborn users -"
    "d /games/steamapps/compatdata 0755 taxborn users -"
  ];

  # borgmatic runs as root, and /mnt/backup is `nofail`. Without something tying
  # repository creation to the mount, a backup taken while the 850 EVO is absent
  # or dead would create the repository path on the root filesystem and quietly
  # fill the array instead of failing. `RequiresMountsFor` means this unit does
  # not run at all when the drive is missing, so the directory never appears and
  # borg fails loudly on a repository that is not there.
  #
  # The repository itself still needs one `borgmatic init --encryption repokey
  # --repository local` by hand, the same as the rsync.net and helium ones.
  systemd.services.borg-local-repo-base = {
    description = "Create the local borg repository base directory";
    wantedBy = [ "multi-user.target" ];
    before = [ "borgmatic.service" ];
    unitConfig.RequiresMountsFor = "/mnt/backup";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe' pkgs.coreutils "mkdir"} -p /mnt/backup/borg";
    };
  };

  myHardware = {
    amd.gpu.enable = true;
    intel.cpu.enable = true;
  };
}
