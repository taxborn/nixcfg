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

  # Everything a desktop $HOME accumulates that is large, rewritten constantly,
  # and either regenerated on demand or re-downloadable. `commonExcludes` was
  # written against servers, where /home holds a shell history and little else;
  # on a workstation those same three source directories pull in browser and
  # Electron caches, Steam's runtime, and every virtualenv and direnv on the
  # machine. That is tens of gigabytes of pure churn going off-site nightly —
  # the same problem uranium's compatdata split solves, one directory over, and
  # worse, because none of it dedups between runs.
  desktopExcludes = [
    # XDG cache, and the same directory wherever else it turns up
    "**/.cache"

    # Chromium and Electron apps keep caches under .config, not .cache, so the
    # pattern above misses them entirely — this is most of the win on a machine
    # running an editor and a chat client.
    "**/.config/*/Cache"
    "**/.config/*/CachedData"
    "**/.config/*/Code Cache"
    "**/.config/*/GPUCache"
    "**/.config/*/Service Worker/CacheStorage"

    # Steam's default library and its runtimes. On uranium the library itself
    # lives on the games drive, but the runtime and shader caches still land
    # here, and on a host without that drive this is the whole library.
    "/home/*/.local/share/Steam"
    "/home/*/.steam"

    # flatpak runtimes and per-app caches
    "/home/*/.local/share/flatpak"
    "/home/*/.var/app/*/cache"

    # already deleted
    "/home/*/.local/share/Trash"

    # reproducible from a lockfile, a flake, or the network
    "**/.venv"
    "**/.direnv"
    "**/.gradle/caches"
    "**/.cargo/registry"
  ];

  # Whether this host replaces a live database with a logical dump in the
  # archive. Everything below that is about dumps rather than about one
  # particular engine keys off this, so adding a third hook later is one more
  # disjunct rather than a sweep through the file.
  takesDumps = cfg.client.postgresqlDumpAll || cfg.client.sqliteDatabases != { };

  # borgmatic stages database dumps on disk and hands borg the staging path as
  # an extra source, so an exclude covering that path silently drops the dump:
  # the dump still runs, the archive is still created, borgmatic still reports
  # success, and the database is simply not in the backup. Nothing surfaces it
  # except restoring — or the dump assertion in `scripts/backup-restore-test.sh`,
  # which is how this was caught.
  #
  # Which path it uses depends on how borgmatic was started, so both have to go:
  #   /run  — the packaged unit sets RuntimeDirectory=borgmatic, giving
  #           /run/./borgmatic (the `/./` is borg's slashdot hack, so the
  #           archive stores it as plain `borgmatic/…`)
  #   /tmp  — the fallback when neither XDG_RUNTIME_DIR nor a systemd
  #           RuntimeDirectory is set, which is the case running `borgmatic`
  #           by hand over ssh, exactly as the restore test does
  #
  # Dropping these is safe as long as `paths` stays below them, which it is:
  # /home, /var/lib, and /etc never traverse /run or /tmp, so the excludes were
  # inert for file selection and doing nothing but this harm. Revisit if a host
  # ever backs up / or /var wholesale.
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

      desktopExcludes = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Also exclude the caches, runtimes, and re-downloadable data that a
          desktop `$HOME` accumulates. Enable on any host someone logs into
          graphically.

          The module's default excludes were written against servers, where
          `/home` is nearly empty. A workstation backing up the same three
          directories ships browser caches, Electron app caches (which live
          under `.config`, not `.cache`), Steam runtimes, and every virtualenv
          and direnv on the machine — tens of gigabytes that change every day,
          dedup poorly between runs, and restore to nothing anyone wants.

          Deliberately not on by default and not implied by
          `profiles.workstation`: what counts as disposable under `/home` is a
          judgement about the host, and getting it wrong silently drops data.
          `~/Downloads` is left *in* for the same reason.
        '';
      };

      postgresqlDumpAll = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = ''
          Capture every PostgreSQL database as a consistent logical dump
          (`pg_dumpall`) inside each archive, and exclude the live
          `/var/lib/postgresql` data directory.

          Copying a running cluster's files is not a backup: borg walks them
          over a period during which the cluster keeps writing, so the archive
          holds a torn mix of pages whose recovery depends on catching a
          checkpoint at the right moment. The dump is taken through the server
          itself and is consistent by construction, and borgmatic replays it on
          `borgmatic restore`. Enable this on any host running PostgreSQL.
        '';
      };

      sqliteDatabases = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = lib.literalExpression ''
          { forgejo = "/var/lib/forgejo/data/forgejo.db"; }
        '';
        description = ''
          Database name -> path of a SQLite file to capture as a logical dump
          (`sqlite3 .dump`) inside each archive. The live file, and its `-wal`
          and `-shm` companions, are excluded in favour of that dump.

          Same reasoning as `postgresqlDumpAll`, and if anything a sharper
          version of it: most of a busy SQLite database's recent history lives
          *outside* the file it is named after, in the write-ahead log, and borg
          reaches the two at different moments. A `-wal` archived out of step
          with its database is a torn pair, and the pair is what recovery reads.
          The dump goes through SQLite itself and sees one consistent snapshot.

          The name is a label for `borgmatic restore --database <name>`, not
          something the file has to be called. Restoring writes the dump back
          over the live path, replacing whatever is there.
        '';
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

      sshPort = lib.mkOption {
        type = lib.types.port;
        default = 2222;
        description = ''
          Port the server's sshd offers borg on, and the port clients address.

          Deliberately not 22. Where Tailscale SSH is enabled it answers port 22
          on the tailnet address by tailnet identity and never reads
          `authorized_keys`, which skips the forced command below and leaves the
          client unconfined. Every client reaches this host over the tailnet, so
          on 22 the restriction would be decorative. Tailscale intercepts only
          22, so any other port is served by real sshd with the forced command
          applied.

          Declared here rather than on the server alone because `knownHosts`
          needs the same number — ssh records a non-default port as
          `[host]:port`, and a mismatch fails host key verification on every
          backup run.
        '';
      };

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
              }:${toString cfg.server.sshPort}/${backupServer.basePath}/${hostname}";
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
            exclude_patterns =
              (if takesDumps then lib.subtractLists dumpStagingPaths commonExcludes else commonExcludes)
              ++ lib.optionals cfg.client.desktopExcludes desktopExcludes
              # superseded by the logical dumps configured below
              ++ lib.optional cfg.client.postgresqlDumpAll "/var/lib/postgresql"
              # the trailing glob takes the `-wal` and `-shm` sidecars with it,
              # which are half the database while the service is running
              ++ lib.mapAttrsToList (_: path: "${path}*") cfg.client.sqliteDatabases
              ++ cfg.client.extraExcludes;
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
          // lib.optionalAttrs cfg.client.postgresqlDumpAll {
            # `username` with no `password` and no `pg_dump_command` is load
            # bearing in a way that is easy to undo by accident: that exact
            # combination is what makes the nixpkgs borgmatic module wrap the
            # dump in `sudo -u postgres` *and* relax the hardened unit
            # (NoNewPrivileges = false, CAP_SETUID/CAP_SETGID) so the user
            # switch is permitted. Supplying an equivalent command by hand —
            # runuser, or an explicit pg_dumpall — opts out of that relaxation
            # and the dump dies with "cannot set groups: Operation not
            # permitted". The user switch itself is needed because the cluster
            # trusts peer authentication, not a password.
            postgresql_databases = [
              {
                name = "all";
                username = "postgres";
              }
            ];
          }
          // lib.optionalAttrs (cfg.client.sqliteDatabases != { }) {
            # No `username` here, and deliberately: borgmatic reads the file
            # directly and the unit already runs as root, so there is no user to
            # switch to and none of the postgres hook's unit relaxation applies.
            # The nixpkgs module fills in `sqlite_command` from pkgs.sqlite.
            sqlite_databases = lib.mapAttrsToList (name: path: {
              inherit name path;
            }) cfg.client.sqliteDatabases;
          }
        ) cfg.client.repositories;
      };
    })

    (lib.mkIf cfg.server.enable {
      environment.systemPackages = [ pkgs.borgbackup ];

      # sshd answers borg on its own port so the forced command below actually
      # binds; see the `sshPort` description. `openFirewall` would punch a hole
      # for both ports on every interface, so it is off and 22 is opened by
      # hand — the borg port stays reachable over the tailnet only, because the
      # tailscale interface is in `trustedInterfaces`.
      services.openssh = {
        ports = [
          22
          cfg.server.sshPort
        ];
        openFirewall = false;
      };
      networking.firewall.allowedTCPPorts = [ 22 ];

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
      #
      # This only binds where sshd is the thing answering, which is why clients
      # address `sshPort` rather than 22 and why Helium turns Tailscale SSH off
      # (`hosts/helium`). On 22 with Tailscale SSH enabled, none of it applies.
      users.users.${backupServer.user}.openssh.authorizedKeys.keys = lib.mapAttrsToList (
        client: pubkey:
        "command=\"${lib.getExe' pkgs.borgbackup "borg"} serve --restrict-to-path ${backupServer.basePath}/${client}\",restrict ${lib.trim pubkey}"
      ) cfg.server.authorizedKeys;
    })
  ];
}
