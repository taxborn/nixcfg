{
  config,
  lib,
  pkgs,
  ...
}:
let
  btrfsFSDevices = lib.unique (
    map (fs: fs.device) (
      lib.attrValues (lib.filterAttrs (_: fs: fs.fsType == "btrfs") config.fileSystems)
    )
  );

  beesdConfig = lib.listToAttrs (
    map (device: {
      name = lib.strings.sanitizeDerivationName (baseNameOf device);

      value = {
        hashTableSizeMB = 2048;
        spec = device;
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

  cfg = config.homelab.btrfs;

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
  options.homelab.btrfs = {
    deduplicate = lib.mkEnableOption ''
      block-level deduplication with bees.

      Each btrfs filesystem on the host gets its own 2 GiB hash table, mapped
      for as long as the daemon runs. Leave this off unless duplicate blocks
      justify that memory use and the background I/O
    '';

    guiTools = lib.mkEnableOption ''
      graphical btrfs tooling (snapper-gui).

      Off by default because this profile is enabled on every host: the servers
      were carrying a GTK application none of them can display. Set by
      `modules/nixos/workstation`
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

  config = {
    environment.systemPackages = lib.optional cfg.guiTools pkgs.snapper-gui;

    # Snapper timelines must never reach an archive.
    homelab.backups.extraExcludes = lib.mapAttrsToList (
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

    systemd.services.snapper-timeline =
      lib.mkIf (btrfsFSDevices != [ ] && cfg.snapshotSubvolumes != { })
        {
          unitConfig.RequiresMountsFor = lib.attrValues cfg.snapshotSubvolumes;
        };
  };
}
