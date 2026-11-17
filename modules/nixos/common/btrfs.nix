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
    deduplicate = lib.mkEnableOption "block-level deduplication with bees";

    guiTools = lib.mkEnableOption "snapper-gui";

    snapshotSubvolumes = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        { compatdata = "/games/steamapps/compatdata"; }
      '';
      description = "Snapper config name to subvolume path, snapshotted alongside `/home`.";
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
