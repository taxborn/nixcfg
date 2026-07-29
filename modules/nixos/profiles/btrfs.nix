{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Compute a list of Btrfs file systems (with mountPoint and device)
  btrfsFSDevices =
    let
      # Helper: does a device already appear in the accumulator?
      isDeviceInList = list: device: builtins.any (e: e.device == device) list;

      # Helper: keep only the first occurrence of each device
      uniqueDeviceList = lib.foldl' (
        acc: e: if isDeviceInList acc e.device then acc else acc ++ [ e ]
      ) [ ];
    in
    uniqueDeviceList (
      lib.mapAttrsToList (_: fs: {
        inherit (fs) mountPoint device;
      }) (lib.filterAttrs (_: fs: fs.fsType == "btrfs") config.fileSystems)
    );

  # Create beesd.filesystems attrset keyed by device basename, with spec = device path
  beesdConfig = lib.listToAttrs (
    map (fs: {
      name = lib.strings.sanitizeDerivationName (baseNameOf fs.device);

      value = {
        hashTableSizeMB = 2048;
        spec = fs.device;
        verbosity = "info";

        extraOptions = [
          "--loadavg-target"
          "1.0"
          "--thread-factor"
          "0.50"
        ];
      };
    }) btrfsFSDevices
  );

  cfg = config.myNixOS.profiles.btrfs;

  # Check if a btrfs /home entry exists
  hasHomeSubvolume =
    lib.hasAttr "/home" config.fileSystems && config.fileSystems."/home".fsType == "btrfs";

  timelineConfig = subvolume: {
    ALLOW_GROUPS = [ "users" ];
    SUBVOLUME = subvolume;
    TIMELINE_CLEANUP = true;
    TIMELINE_CREATE = true;
  };
in
{
  options.myNixOS.profiles.btrfs = {
    enable = lib.mkEnableOption "btrfs filesystem configuration";
    deduplicate = lib.mkEnableOption "deduplicate btrfs filesystems";

    guiTools = lib.mkEnableOption ''
      graphical btrfs tooling (snapper-gui).

      Off by default because this profile is enabled on every host: the servers
      were carrying a GTK application none of them can display. Set by
      `profiles.workstation`
    '';

    snapshotSubvolumes = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        { compatdata = "/games/steamapps/compatdata"; }
      '';
      description = ''
        Snapper config name -> subvolume path, for subvolumes that should get
        timeline snapshots on top of `/home`.

        `/home` is picked up on its own wherever it is a btrfs subvolume, which
        covers the root array. This is for the ones that are not derivable that
        way — in practice, subvolumes on a companion drive, where the interesting
        question is which parts of the drive are worth snapshotting at all
        rather than whether the drive is btrfs.

        Each subvolume named here needs a `.snapshots` subvolume beneath it. The
        NixOS snapper module writes config files and nothing else, so that has to
        come from the disko layout — see modules/disko for how the existing
        /home/.snapshots is declared.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = lib.optional cfg.guiTools pkgs.snapper-gui;

    # Keep every snapshotted subvolume's `.snapshots` out of the archives.
    # Snapper holds a timeline of full subtrees, so a backup path that contains
    # one hands borg every retained snapshot as well as the live data — the
    # exact mistake `/home/.snapshots` in the backup module's own excludes
    # already avoids, one subvolume over. Derived from `snapshotSubvolumes`
    # rather than written per host because the host that adds the next
    # subvolume is the host that forgets.
    myNixOS.services.backups.client.extraExcludes = lib.mapAttrsToList (
      _: subvolume: "${subvolume}/.snapshots"
    ) cfg.snapshotSubvolumes;

    services = lib.mkIf (btrfsFSDevices != [ ]) {
      beesd.filesystems = lib.mkIf cfg.deduplicate beesdConfig;
      btrfs.autoScrub.enable = true;

      snapper = {
        configs =
          lib.optionalAttrs hasHomeSubvolume { home = timelineConfig "/home"; }
          // lib.mapAttrs (_: timelineConfig) cfg.snapshotSubvolumes;

        filters = ''
          -.bash_profile
          -.bashrc
          -.cache
          -.config
          -.local
          -.mozilla
          -.nix-profile
          -.pki
          -.share
          -.snapshots
        '';

        persistentTimer = true;
      };
    };
  };
}
