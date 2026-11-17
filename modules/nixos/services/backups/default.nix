{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.homelab.backups;
  hostname = config.networking.hostName;
  networkMap = config.homelab.services;
  addr = config.homelab.tailscale.address;

  backupServer = config.homelab.backupServer;

  commonExcludes = [
    "/nix"

    "/tmp"
    "/var/tmp"
    "/run"
    "/var/lib/systemd"
    "/var/log/journal"

    "/home/.snapshots"

    # Scoped to ~/dev. A bare `**/target` once matched a knot ref under /var/lib.
    "/home/${config.homelab.owner.username}/dev/**/target"
    "/home/${config.homelab.owner.username}/dev/**/node_modules"
    "/home/${config.homelab.owner.username}/dev/**/__pycache__"
  ];

  desktopExcludes = [
    "**/.cache"

    "**/.config/*/Cache"
    "**/.config/*/CachedData"
    "**/.config/*/Code Cache"
    "**/.config/*/GPUCache"
    "**/.config/*/Service Worker/CacheStorage"

    "/home/*/.local/share/Steam"
    "/home/*/.steam"

    "/home/*/.local/share/flatpak"
    "/home/*/.var/app/*/cache"

    "/home/*/.local/share/Trash"

    "/home/*/.npm"
    "/home/*/.local/share/containers/storage/overlay"
    "/home/*/.local/share/claude/versions"
    "/home/*/.local/share/zed/external_agents"
    "/home/*/.local/share/zed/languages"

    "**/.venv"
    "**/.direnv"
    "**/.gradle/caches"
    "**/.cargo/registry"
  ];

  takesDumps = cfg.postgresqlDumpAll || cfg.sqliteDatabases != { };

  # An exclude covering the dump staging path drops every database from the archive
  # while borgmatic still reports success. See docs/backups.md#databases.
  dumpStagingPaths = [
    "/run"
    "/tmp"
    "/var/tmp"
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
  options.homelab.backups = {
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

    desktopExcludes = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Also exclude a desktop `$HOME`'s caches and re-downloadable data.";
    };

    postgresqlDumpAll = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Archive a `pg_dumpall` dump instead of the live PostgreSQL directory.";
    };

    sqliteDatabases = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      example = lib.literalExpression ''
        { tealfm-piper = "/var/lib/tealfm-piper/piper.db"; }
      '';
      description = "Name to SQLite path, archived as a `.dump` instead of the live file.";
    };

    repositories = lib.mkOption {
      type = lib.types.attrsOf repoOpts;
      default = { };
      description = "Borg repositories. Every host gets `rsync` and the backup server's by default.";
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

  config = lib.mkMerge [
    {
      homelab.backups.repositories = {
        rsync = lib.mkDefault {
          path = "ssh://${config.homelab.rsyncNet.user}@${config.homelab.rsyncNet.host}/./borg/${hostname}";
          label = "rsync";
          remotePath = "borg14";
        };

        ${backupServer.host} = lib.mkDefault {
          label = backupServer.host;
          path =
            if hostname == backupServer.host then
              "${backupServer.basePath}/${hostname}"
            else
              # The double slash makes the path absolute.
              "ssh://${backupServer.user}@${
                config.homelab.hosts.${backupServer.host}
              }:${toString backupServer.port}/${backupServer.basePath}/${hostname}";
        };
      };

      # known_hosts matches a non-default port separately from 22.
      programs.ssh.knownHosts."${backupServer.host}-borg" = {
        hostNames = [
          "[${config.homelab.hosts.${backupServer.host}}]:${toString backupServer.port}"
        ];
        publicKeyFile = "${self}/keys/root_${backupServer.host}.pub";
      };

      # Verified against rsync.net's signed fingerprint list. Re-verify before replacing.
      programs.ssh.knownHosts."rsync-net-ed25519" = {
        hostNames = [ config.homelab.rsyncNet.host ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObQN4P/deJ/k4P4kXh6a9K4Q89qdyywYetp9h3nwfPo";
      };
      programs.ssh.knownHosts."rsync-net-ecdsa" = {
        hostNames = [ config.homelab.rsyncNet.host ];
        publicKey = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBC2wi3kWdaW4W+tRu0uq8hhY1ffFbzZ4KCh0FUhFw0GIb8lWWvVnGInc9Tr538k0ZICFSSbs5faMgpMuHSX8QvU=";
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

        ntfyToken = {
          file = "${self}/secrets/ntfy/token.age";
          mode = "0400";
        };
      };

      services.borgmatic = {
        enable = true;

        configurations = lib.mapAttrs (
          _: repo:
          {
            source_directories = cfg.paths;
            repositories = [ { inherit (repo) path label; } ];
            exclude_patterns =
              (if takesDumps then lib.subtractLists dumpStagingPaths commonExcludes else commonExcludes)
              ++ lib.optionals cfg.desktopExcludes desktopExcludes
              ++ lib.optional cfg.postgresqlDumpAll "/var/lib/postgresql"
              # The glob takes the -wal and -shm sidecars with the database.
              ++ lib.mapAttrsToList (_: path: "${path}*") cfg.sqliteDatabases
              ++ cfg.extraExcludes;
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
          // lib.optionalAttrs (lib.hasPrefix "ssh://" repo.path) {
            # The servers enforce append-only, so prune and compact would do nothing.
            skip_actions = [
              "prune"
              "compact"
            ];
          }
          // {
            # Success only. A message that stops arriving is the signal.
            ntfy = {
              server = "https://${networkMap.ntfy.domain}";
              topic = config.homelab.ntfy.topics.backups;
              access_token = "{credential file ${config.age.secrets.ntfyToken.path}}";
              states = [ "finish" ];
              finish = {
                title = "${hostname}: backup ok (${repo.label})";
                message = "borgmatic finished a run against ${repo.label}.";
                priority = "min";
                tags = "white_check_mark";
              };
            };
          }
          // lib.optionalAttrs cfg.postgresqlDumpAll {
            # This exact shape (username, no password, no command) is what lets the nixpkgs
            # module relax the unit for `sudo -u postgres`. See docs/backups.md#databases.
            postgresql_databases = [
              {
                name = "all";
                username = "postgres";
              }
            ];
          }
          // lib.optionalAttrs (cfg.sqliteDatabases != { }) {
            # No username: a SQLite dump must not trigger the postgres unit relaxation.
            sqlite_databases = lib.mapAttrsToList (name: path: {
              inherit name path;
            }) cfg.sqliteDatabases;
          }
        ) cfg.repositories;
      };

      systemd.services.borgmatic = {
        # A switch must not restart a running backup. See docs/backups.md#the-borgmatic-unit.
        restartIfChanged = false;

        serviceConfig = {
          # Turns a wedged run into a failed unit the alert can see.
          TimeoutStartSec = "6h";

          Nice = 19;
          IOSchedulingClass = "idle";
          CPUSchedulingPolicy = "idle";
        };
      };
    }

    (lib.mkIf (hostname == backupServer.host) {
      environment.systemPackages = [ pkgs.borgbackup ];

      # A repository must never end up inside its own backup.
      homelab.backups.extraExcludes = [ backupServer.basePath ];

      # Fails loudly on a missing drive instead of filling the root filesystem.
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

      # 2200 binds the tailnet address only. 22 is listed for both families or it vanishes.
      services.openssh = {
        openFirewall = false;
        ports = [ 22 ];
        listenAddresses = [
          {
            addr = "0.0.0.0";
            port = 22;
          }
          {
            addr = "[::]";
            port = 22;
          }
          {
            inherit addr;
            inherit (backupServer) port;
          }
        ];
      };

      systemd.services.sshd = lib.recursiveUpdate config.homelab.tailscale.bindOrdering {
        unitConfig.StartLimitIntervalSec = lib.mkForce 0;
        serviceConfig.RestartSec = lib.mkForce 5;
      };

      assertions = [
        {
          assertion = config.services.tailscale.enable && addr != null;
          message = ''
            The backup server binds the borg port to this host's
            tailnet address and nowhere else, so the host has to run Tailscale
            and appear in homelab.hosts.
          '';
        }
      ];

      # Each key can only append to its own repository.
      users.users.${backupServer.user}.openssh.authorizedKeys.keys = lib.mapAttrsToList (
        client: _:
        ''command="${lib.getExe pkgs.borgbackup} serve --append-only --restrict-to-path ${backupServer.basePath}/${client}",restrict ${lib.trim (builtins.readFile "${self}/secrets/borg/${client}/ssh_key.pub")}''
      ) (lib.removeAttrs config.homelab.hosts [ backupServer.host ]);
    })
  ];
}
