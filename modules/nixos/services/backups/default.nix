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

  commonExcludes = [
    # large system paths
    "/var/lib/docker"
    "/var/lib/systemd"
    "/var/lib/libvirt"

    # nix store (reproducible, no need to back up)
    "/nix"

    # temporary and runtime files
    "/tmp"
    "/var/tmp"
    "/run"
    "/var/log/journal"

    # swap
    "/swap"
    "*.swp"
    "*.swo"

    # build artifacts
    "**/target"
    "*.pyc"
    "*.o"
    "*.so"
  ];

  desktopExcludes = [
    # gaming
    "/home/*/.local/share/Steam"
    "/home/*/.steam"

    # JS/TS package managers
    "**/node_modules"
    "/home/*/.npm"
    "/home/*/.yarn"
    "/home/*/.pnpm-store"
    "/home/*/.bun"

    # rust
    "/home/*/.cargo"
    "/home/*/.rustup"

    # go
    "/home/*/go/pkg"

    # python
    "**/__pycache__"
    "**/.venv"
    "**/venv"

    # java/jvm
    "/home/*/.gradle"
    "/home/*/.m2"

    # caches and IDE state
    "/home/*/.cache"
    "/home/*/.local/share/Trash"

    # browser profile caches
    "/home/*/.mozilla/firefox/*/cache2"
    "/home/*/.mozilla/firefox/*/startupCache"
    "/home/*/.config/zen/*/cache2"
    "/home/*/.config/zen/*/startupCache"

    # git history (recoverable from remotes)
    "**/.git"
  ];

  repoOpts = lib.types.submodule {
    options = {
      path = lib.mkOption {
        type = lib.types.str;
        description = "Borg repository path (local or ssh://).";
      };
      label = lib.mkOption {
        type = lib.types.str;
        description = "Short label for this repository.";
      };
      remotePath = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Remote borg binary path (e.g. borg14 for rsync.net).";
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

      desktopExcludes = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Exclude Steam, node_modules, cargo, caches, and other desktop dev artifacts.";
      };

      extraExcludes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional exclude patterns.";
      };

      repositories = lib.mkOption {
        type = lib.types.attrsOf repoOpts;
        default = { };
        description = "Named borg repositories to back up to. Merged with any auto-generated repos from enableRsyncRepo/enableHeliumRepo.";
      };

      enableRsyncRepo = lib.mkEnableOption "auto-configure rsync.net borg repository for this host";

      enableHeliumRepo = lib.mkEnableOption "auto-configure helium-01 borg repository for this host";

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
      enable = lib.mkEnableOption "borg backup server (SSH authorized_keys)";

      basePath = lib.mkOption {
        type = lib.types.str;
        default = "/mnt/hdd/borg-repos";
        description = "Base directory for borg repositories.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "taxborn";
        description = "SSH user for borg access.";
      };

      authorizedKeys = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = { };
        description = "Hostname -> SSH public key mapping for borg clients.";
      };
    };
  };

  config =
    let
      autoRepos =
        lib.optionalAttrs cfg.client.enableRsyncRepo {
          rsync = {
            path = "ssh://de4388@de4388.rsync.net/./borg-repos/${hostname}";
            label = "rsync";
            remotePath = "borg14";
          };
        }
        // lib.optionalAttrs cfg.client.enableHeliumRepo {
          helium = {
            path =
              if hostname == "helium-01" then
                "/mnt/hdd/borg-repos/${hostname}"
              else
                "ssh://taxborn@${config.mySnippets.mischief-town.networkMap.tailscaleIPs."helium-01"}//mnt/hdd/borg-repos/${hostname}";
            label = "helium";
            remotePath = null;
          };
        };
      # User-specified repositories take precedence over auto-generated ones.
      effectiveRepositories = autoRepos // cfg.client.repositories;
    in
    lib.mkMerge [
    (lib.mkIf cfg.client.enable {
      assertions = [
        {
          assertion = effectiveRepositories != { };
          message = "myNixOS.services.backups.client.repositories must have at least one repository (or enable enableRsyncRepo/enableHeliumRepo).";
        }
      ];

      environment.systemPackages = [ pkgs.borgmatic ];

      age.secrets.borgPassphrase = {
        file = "${self.inputs.secrets}/borg/${hostname}/passphrase.age";
        mode = "0400";
      };

      age.secrets.borgSshKey = {
        file = "${self.inputs.secrets}/borg/${hostname}/ssh_key.age";
        mode = "0400";
      };

      services.borgmatic = {
        enable = true;
        configurations = lib.mapAttrs (name: repo: {
          source_directories = cfg.client.paths;
          repositories = [
            {
              path = repo.path;
              label = repo.label;
            }
          ];
          exclude_patterns =
            commonExcludes
            ++ (lib.optionals cfg.client.desktopExcludes desktopExcludes)
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
        } // lib.optionalAttrs (repo.remotePath != null) {
          remote_path = repo.remotePath;
        }) effectiveRepositories;
      };
    })

    (lib.mkIf cfg.server.enable {
      environment.systemPackages = [ pkgs.borgbackup ];

      users.users.${cfg.server.user}.openssh.authorizedKeys.keys =
        lib.mapAttrsToList (hostname: pubkey:
          "command=\"borg serve --restrict-to-path ${cfg.server.basePath}/${hostname}\",restrict ${pubkey}"
        ) cfg.server.authorizedKeys;
    })
  ];
}
