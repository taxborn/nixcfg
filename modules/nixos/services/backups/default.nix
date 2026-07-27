{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.backups;
  hostname = config.networking.hostName;

  # Helium keeps the second copy of every host's archives on its external drive.
  # Both halves of that arrangement read from here — the paths `borg serve` is
  # confined to on the server, and the target each client writes to — so the two
  # cannot drift apart. There is one backup server, so this is a constant rather
  # than an option, in the same spirit as the hardcoded rsync.net URL below.
  backupServer = {
    host = "helium";
    user = "taxborn";
    basePath = "/mnt/hdd/borg";
  };

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
  options.myNixOS.services.backups = {
    client = {
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
          rsync.net and Helium repositories by default; setting an attribute of
          the same name replaces it.
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

    server = {
      enable = lib.mkEnableOption "borg repository server, served over restricted SSH";

      authorizedKeys = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = lib.literalExpression ''
          { argon = builtins.readFile "''${self}/secrets/borg/argon/ssh_key.pub"; }
        '';
        description = ''
          Client hostname -> that host's borg SSH public key. Each key is pinned
          to a forced `borg serve` confined to that client's own repository, so
          one compromised host can neither read nor delete another's archives.
        '';
      };
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.client.enable {
      # Two destinations for every host: rsync.net off-site, and Helium's
      # external drive over the tailnet.
      myNixOS.services.backups.client.repositories = {
        rsync = lib.mkDefault {
          path = "ssh://de4388@de4388.rsync.net/./borg/${hostname}";
          label = "rsync";
          remotePath = "borg14";
        };

        ${backupServer.host} = lib.mkDefault {
          label = backupServer.host;
          path =
            if hostname == backupServer.host then
              # The server reaches its own repository through the filesystem
              # rather than ssh'ing to itself.
              "${backupServer.basePath}/${hostname}"
            else
              # borg reads a single slash after the host as home-relative, so
              # the leading slash of basePath is what makes this absolute.
              "ssh://${backupServer.user}@${
                config.mySnippets.tailnet.tailscaleIPs.${backupServer.host}
              }/${backupServer.basePath}/${hostname}";
        };
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
            source_directories = cfg.client.paths;
            repositories = [ { inherit (repo) path label; } ];
            exclude_patterns = commonExcludes ++ cfg.client.extraExcludes;
            exclude_if_present = [ ".nobackup" ];

            encryption_passcommand = "cat ${config.age.secrets.borgPassphrase.path}";
            ssh_command = "ssh -i ${config.age.secrets.borgSshKey.path}";

            compression = "auto,zstd";
            checkpoint_interval = 600;

            keep_daily = cfg.client.retention.keepDaily;
            keep_weekly = cfg.client.retention.keepWeekly;
            keep_monthly = cfg.client.retention.keepMonthly;
            keep_yearly = cfg.client.retention.keepYearly;

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
        ) cfg.client.repositories;
      };
    })

    (lib.mkIf cfg.server.enable {
      environment.systemPackages = [ pkgs.borgbackup ];

      # A repository must never end up inside its own backup. Inert today — the
      # default source directories don't reach the drive — but load-bearing the
      # moment a data service living there joins the backup set.
      myNixOS.services.backups.client.extraExcludes = [ backupServer.basePath ];

      # The drive is mounted `nofail`, so it can be absent at boot. Creating the
      # base directory as an unprivileged user, and only once the mount is up,
      # means a missing drive fails the backup loudly instead of quietly filling
      # the root filesystem with archives — /mnt/hdd itself is root-owned 0755,
      # so `borg serve` cannot create anything under it on its own.
      systemd.services.borg-repo-base = {
        description = "Create the borg repository base directory";
        wantedBy = [ "multi-user.target" ];
        unitConfig.RequiresMountsFor = backupServer.basePath;
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = backupServer.user;
          ExecStart = "${lib.getExe' pkgs.coreutils "mkdir"} -p ${backupServer.basePath}";
        };
      };

      # `restrict` drops pty allocation, port forwarding, agent forwarding, and
      # user rc; the forced command means the key can do nothing but serve that
      # one repository, whatever the client asks for.
      users.users.${backupServer.user}.openssh.authorizedKeys.keys = lib.mapAttrsToList (
        client: pubkey:
        "command=\"${lib.getExe' pkgs.borgbackup "borg"} serve --restrict-to-path ${backupServer.basePath}/${client}\",restrict ${lib.trim pubkey}"
      ) cfg.server.authorizedKeys;
    })
  ];
}
