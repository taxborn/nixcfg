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
  networkMap = config.mySnippets.biscuits-at.networkMap;
  addr = config.myNixOS.services.tailscale.address;

  # Helium keeps the second copy of every host's archives on its external drive.
  # Both halves of that arrangement read from here — the paths `borg serve` is
  # confined to on the server, and the target each client writes to — so the two
  # cannot drift apart. There is one backup server, so this is a constant rather
  # than an option, in the same spirit as the hardcoded rsync.net URL below.
  backupServer = {
    host = "helium";
    user = "taxborn";
    basePath = "/mnt/hdd/borg";
    # Real sshd, not Tailscale SSH. Tailscale answers 22 on the tailnet address
    # and authorises by tailnet identity, so an `authorized_keys` entry there is
    # never read and its forced command never runs. Anything that has to be
    # confined to one repository has to arrive on a port Tailscale leaves alone.
    port = 2200;
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
  # Which path it uses depends on how borgmatic was started, so both have to
  # go, and the list drops `/var/tmp` alongside them:
  #   /run  — the packaged unit sets RuntimeDirectory=borgmatic, giving
  #           /run/./borgmatic (the `/./` is borg's slashdot hack, so the
  #           archive stores it as plain `borgmatic/…`)
  #   /tmp  — the fallback when neither XDG_RUNTIME_DIR nor a systemd
  #           RuntimeDirectory is set, which is the case running `borgmatic`
  #           by hand over ssh, exactly as the restore test does
  #
  # Dropping these is safe as long as `paths` stays below them, which it is:
  # /home, /var/lib, and /etc never traverse /run, /tmp, or /var/tmp, so the
  # excludes were inert for file selection and doing nothing but this harm.
  # Revisit if a host ever backs up / or /var wholesale.
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

      notify = {
        enable = lib.mkEnableOption "an ntfy message after each successful backup";

        topic = lib.mkOption {
          type = lib.types.str;
          default = "backups";
          description = ''
            Topic the messages go to. The server's access rules in
            `secrets/ntfy.age` name this topic, so changing it here without
            changing them there gets every publish rejected with a 403.
          '';
        };
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
      enable = lib.mkEnableOption "borg repository server, served over SSH";

      authorizedKeys = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        example = lib.literalExpression ''
          { argon = builtins.readFile "''${self}/secrets/borg/argon/ssh_key.pub"; }
        '';
        description = ''
          Client hostname -> that host's borg SSH public key, authorized for
          the backup user. Each key is confined to `borg serve` on that
          client's own repository.
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
              }:${toString backupServer.port}/${backupServer.basePath}/${hostname}";
        };
      };

      # known_hosts matches a non-default port as `[name]:port`, so the pin the
      # snippet holds for port 22 does not cover this one, and the first backup
      # would stop at an unknown host key.
      programs.ssh.knownHosts."${backupServer.host}-borg" = {
        hostNames = [
          "[${config.mySnippets.tailnet.tailscaleIPs.${backupServer.host}}]:${toString backupServer.port}"
        ];
        publicKeyFile = "${self}/keys/root_${backupServer.host}.pub";
      };

      # rsync.net's host keys, pinned so the first connection is not trust on
      # first use. Taken with ssh-keyscan and checked against the PGP-signed
      # list at https://www.rsync.net/resources/fingerprints.txt, where the
      # three SHA256 fingerprints match the de6 to de9 entries. If rsync.net
      # rotates them the backup stops at an unknown host key, which is the
      # point; re-verify against that list before replacing these.
      programs.ssh.knownHosts."rsync-net-ed25519" = {
        hostNames = [ "de4388.rsync.net" ];
        publicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIObQN4P/deJ/k4P4kXh6a9K4Q89qdyywYetp9h3nwfPo";
      };
      programs.ssh.knownHosts."rsync-net-ecdsa" = {
        hostNames = [ "de4388.rsync.net" ];
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
      }
      // lib.optionalAttrs cfg.client.notify.enable {
        # One write-only token for every host rather than one each. It can
        # publish to a single topic and read nothing, so a host leaking it
        # allows fake "backup ok" messages and no more.
        ntfyToken = {
          file = "${self}/secrets/ntfy/token.age";
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
          // lib.optionalAttrs cfg.client.notify.enable {
            # Success only, on purpose. borgmatic's default is to ping on
            # failure, but a failure message needs the run to get as far as
            # sending one, and the failures that matter here (a wedged borg, a
            # host that is down) never do. A message that stops arriving is
            # the signal, so the thing to send is the one that only a working
            # backup can.
            #
            # borgmatic runs once per repository, so every host sends one
            # message per copy. The label in the title is what tells the
            # rsync.net one from Helium's.
            ntfy = {
              server = "https://${networkMap.ntfy.domain}";
              inherit (cfg.client.notify) topic;
              # An `access_token` rather than a username and password, so the
              # credential is scoped to the one write-only user.
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

      systemd.services.borgmatic = {
        # A `nixos-rebuild switch` has no business touching a backup that is
        # already running, and by default it restarts this unit like any other.
        # That does two bad things at once: the switch blocks on the start job
        # for as long as a full run takes, and the SIGTERM that precedes the
        # restart kills borg mid-archive, leaving a stale lock in
        # /root/.cache/borg that the replacement run then times out against.
        # Argon lost eight days of backups to exactly that sequence. The timer
        # decides when a backup runs; a configuration change lands on the next
        # scheduled one.
        restartIfChanged = false;

        serviceConfig = {
          # `Type=oneshot` defaults TimeoutStartSec to infinity, so a run that
          # wedges sits in `activating` forever instead of failing. That is how
          # those eight days went unnoticed: the fleet alert watches
          # `node_systemd_unit_state{state="failed"}`, and a unit that never
          # fails never alerts. The wedge itself is borgmatic's — when borg
          # exits early, the database dump processes are left blocked writing
          # to a named pipe nothing will ever read. Six hours is far past any
          # run these hosts do, so the only thing this bound catches is a hang,
          # and it turns that hang into something the alert can see.
          #
          # Recovery after one fires is `borgmatic break-lock`, since the
          # timeout kill leaves behind the same stale lock a switch used to.
          # Deliberately not automated: breaking a lock a live borg still holds
          # is worse than the wedge.
          TimeoutStartSec = "6h";

          # The packaged timer is `OnCalendar=daily` with `Persistent=true`,
          # which is the right shape and should stay: on a laptop asleep at
          # midnight the catch-up run is the only run that ever happens. The
          # cost is that it fires the instant the machine wakes — on Tungsten
          # it last started in the same second as resume — and then spends a
          # minute and a half competing with a desktop that is still coming up.
          #
          # The fix is priority, not schedule. borg is I/O bound, so idle I/O
          # scheduling is what does the work here; the CPU settings just keep
          # the compression from being felt. The backup still starts promptly,
          # which is what a machine that is rarely awake needs, it simply
          # yields to anything a person is waiting on.
          Nice = 19;
          IOSchedulingClass = "idle";
          CPUSchedulingPolicy = "idle";
        };
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

      # 22 keeps listening on every interface, as before. 2200 binds the
      # tailnet address alone, so it exists nowhere else even if the firewall
      # is ever opened or `tailscale0` stops being trusted. The closed firewall
      # used to be the only thing keeping it there. `openFirewall` stays off
      # because it would open both ports, and 22 stays open through
      # `programs.ssh` instead.
      #
      # An explicit port on any `listenAddresses` entry replaces sshd's
      # wildcard listener, so 22 has to be listed for both families or it
      # would vanish. `ports` stays at 22 so a stray `Port` line cannot put
      # 2200 back on the wildcard.
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

      # The tailnet address only exists once tailscaled is Running. sshd carries
      # on with the listeners that did bind, so losing the race at boot leaves
      # 22 answering and 2200 dead, and every client's backup refused with
      # notifications success-only. The nixpkgs unit sets its own restart
      # policy, so the shared values are forced.
      systemd.services.sshd = lib.recursiveUpdate config.myNixOS.services.tailscale.bindOrdering {
        unitConfig.StartLimitIntervalSec = lib.mkForce 0;
        serviceConfig.RestartSec = lib.mkForce 5;
      };

      assertions = [
        {
          assertion = config.services.tailscale.enable && addr != null;
          message = ''
            myNixOS.services.backups.server binds the borg port to this host's
            tailnet address and nowhere else, so the host has to run Tailscale
            and appear in mySnippets.tailnet.tailscaleIPs.
          '';
        }
      ];

      # Each client key can run `borg serve` on its own repository and nothing
      # else, whatever command it asks for. `restrict` drops the pty,
      # forwarding and agent access the entry would otherwise grant. The full
      # store path is needed because a forced command runs without the system
      # PATH.
      #
      # This confines a key arriving on `backupServer.port`. It does not stop a
      # compromised host reaching a shell on 22 by tailnet identity, which only
      # the tailnet ACLs can close.
      users.users.${backupServer.user}.openssh.authorizedKeys.keys = lib.mapAttrsToList (
        client: pubkey:
        ''command="${lib.getExe pkgs.borgbackup} serve --restrict-to-path ${backupServer.basePath}/${client}",restrict ${lib.trim pubkey}''
      ) cfg.server.authorizedKeys;
    })
  ];
}
