{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.backups.client;
  hostname = config.networking.hostName;

  # Paths that are reproducible, volatile, or already represented elsewhere in
  # the archive. Host-specific noise belongs in `extraExcludes`.
  commonExcludes = [
    # rebuilt from the flake
    "/nix"

    # runtime and volatile state
    "/tmp"
    "/var/tmp"
    "/run"
    "/var/lib/systemd"
    "/var/log/journal"

    # snapper snapshots of /home, which is backed up directly
    "/home/.snapshots"

    # build artifacts
    "**/target"
    "**/node_modules"
    "**/__pycache__"
  ];

  repoOpts = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        description = "Borg repository path (local or ssh://).";
      };

      label = lib.mkOption {
        type = lib.types.str;
        description = "Short label for this repository, used by `borgmatic --repository`.";
      };

      remotePath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Remote borg binary to invoke (e.g. `borg14` on rsync.net).";
      };
    };
  };
in
{
  options.myNixOS.services.backups.client = {
    enable = lib.mkEnableOption "borgmatic backup client";

    paths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "/home"
        "/var/lib"
        "/etc"
      ];
      description = "Directories to back up.";
    };

    extraExcludes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Additional exclude patterns, on top of the module's defaults.";
    };

    repositories = lib.mkOption {
      type = lib.types.attrsOf repoOpts;
      default = { };
      description = ''
        Named borg repositories to back up to. Every enabled host gets the
        rsync.net repository by default; setting an attribute of the same name
        replaces it.
      '';
    };

    retention = {
      keepDaily = lib.mkOption {
        type = lib.types.int;
        default = 7;
        description = "Number of daily archives to keep.";
      };

      keepWeekly = lib.mkOption {
        type = lib.types.int;
        default = 4;
        description = "Number of weekly archives to keep.";
      };

      keepMonthly = lib.mkOption {
        type = lib.types.int;
        default = 6;
        description = "Number of monthly archives to keep.";
      };

      keepYearly = lib.mkOption {
        type = lib.types.int;
        default = 1;
        description = "Number of yearly archives to keep.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # rsync.net is the only target that exists today. Helium's repo joins it as
    # a second entry once that host is formatted (TODO.md, phase 3).
    myNixOS.services.backups.client.repositories.rsync = lib.mkDefault {
      path = "ssh://de4388@de4388.rsync.net/./borg/${hostname}";
      label = "rsync";
      remotePath = "borg14";
    };

    age.secrets = {
      borgPassphrase = {
        file = "${self}/secrets/borg/${hostname}/passphrase.age";
        mode = "0400";
      };

      borgSshKey = {
        file = "${self}/secrets/borg/${hostname}/ssh_key.age";
        mode = "0400";
      };
    };

    services.borgmatic = {
      enable = true;

      # One borgmatic configuration per repository: `remote_path` is per-config,
      # and rsync.net needs it. borgmatic's timer walks every config in one run.
      configurations = lib.mapAttrs (
        _: repo:
        {
          source_directories = cfg.paths;
          repositories = [ { inherit (repo) path label; } ];
          exclude_patterns = commonExcludes ++ cfg.extraExcludes;
          exclude_if_present = [ ".nobackup" ];

          encryption_passcommand = "cat ${config.age.secrets.borgPassphrase.path}";
          ssh_command = "ssh -i ${config.age.secrets.borgSshKey.path}";

          compression = "auto,zstd";
          checkpoint_interval = 600;

          keep_daily = cfg.retention.keepDaily;
          keep_weekly = cfg.retention.keepWeekly;
          keep_monthly = cfg.retention.keepMonthly;
          keep_yearly = cfg.retention.keepYearly;

          checks = [
            {
              name = "repository";
              frequency = "2 weeks";
            }
            {
              name = "archives";
              frequency = "1 month";
            }
          ];
        }
        // lib.optionalAttrs (repo.remotePath != null) {
          remote_path = repo.remotePath;
        }
      ) cfg.repositories;
    };
  };
}
