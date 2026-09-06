{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myNixOS.services.forgejo-runner;
  user = "forgejo-runner";
  uid = 990;
  stateDir = "/var/lib/${user}";
  baseConfig = pkgs.writeText "forgejo-runner.json" (
    builtins.toJSON {
      log.level = "info";
      runner = {
        capacity = 1;
        timeout = "1h";
        shutdown_timeout = "1m";
        insecure = false;
        labels = [ "debian:docker://docker.io/library/node:24-bookworm" ];
      };
      # The cache proxy needs a listener reachable from job containers. Leave it
      # off until it has an explicit place in the network policy.
      cache.enabled = false;
      container = {
        network = "";
        privileged = false;
        valid_volumes = [ ];
        # DOCKER_HOST selects the rootless socket for the runner. This separate
        # setting prevents the runner from mounting that socket inside jobs.
        docker_host = "-";
        options = "--cpus=2 --memory=4g --pids-limit=512";
        force_pull = true;
      };
      server.connections.forgejo.url = "https://${config.mySnippets.biscuits-at.networkMap.forgejo.domain}/";
    }
  );
in
{
  options.myNixOS.services.forgejo-runner = {
    enable = lib.mkEnableOption "Forgejo runner for trusted repositories";
    credentialsFile = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/forgejo-runner-credentials/connection.json";
      description = ''
        Root-owned runtime JSON file containing the runner's UUID and token.
        Keep it outside the Nix store. The service stays stopped until this
        file exists; see the module README for v16 registration.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.myNixOS.services.forgejo.enable;
        message = "Keep CI jobs off the host holding Forgejo's repositories and credentials.";
      }
      {
        assertion = !config.myNixOS.services.backups.server.enable;
        message = "Keep CI jobs off the fleet's backup server.";
      }
      {
        assertion =
          lib.hasPrefix "/" cfg.credentialsFile && !(lib.hasPrefix "/nix/store/" cfg.credentialsFile);
        message = "Forgejo runner credentials must be an absolute runtime path outside the Nix store.";
      }
    ];

    virtualisation.podman.enable = true;
    # Container layers and workspaces are disposable and can change while
    # borg walks /var/lib. The sibling credential directory remains backed up.
    myNixOS.services.backups.client.extraExcludes =
      lib.mkIf config.myNixOS.services.backups.client.enable
        [
          stateDir
        ];
    # The upstream module enables both sockets. Only the user socket is used
    # here; giving this account the system socket would grant host root.
    systemd.sockets.podman.enable = false;
    systemd.services.podman.enable = false;

    users.groups.${user} = { };
    users.users.${user} = {
      inherit uid;
      isSystemUser = true;
      group = user;
      home = stateDir;
      createHome = true;
      homeMode = "0700";
      autoSubUidGidRange = true;
      linger = true;
    };

    # Podman creates container scopes under this user manager, outside the
    # runner service's cgroup. Limit the whole user slice so service containers
    # cannot evade the budget by multiplying within a single workflow.
    systemd.slices."user-${toString uid}".sliceConfig = {
      CPUQuota = "400%";
      MemoryHigh = "5G";
      MemoryMax = "6G";
      TasksMax = 4096;
    };

    systemd.tmpfiles.rules = [ "d /var/lib/forgejo-runner-credentials 0700 root root -" ];

    # The upstream runner module currently assumes rootful Podman and a UUID
    # known at evaluation time. Assemble its JSON-compatible YAML at runtime
    # so registration can happen after the host has been built.
    systemd.services.forgejo-runner = {
      description = "Forgejo runner for trusted repositories";
      wantedBy = [ "multi-user.target" ];
      wants = [ "network-online.target" ];
      requires = [ "user@${toString uid}.service" ];
      after = [
        "network-online.target"
        "user@${toString uid}.service"
      ];
      unitConfig.ConditionPathExists = cfg.credentialsFile;
      environment = {
        HOME = stateDir;
        XDG_RUNTIME_DIR = "/run/user/${toString uid}";
        DOCKER_HOST = "unix:///run/user/${toString uid}/podman/podman.sock";
      };
      preStart = ''
        umask 077
        ${lib.getExe pkgs.jq} -e --slurpfile credential "$CREDENTIALS_DIRECTORY/connection" '
          if ($credential | length) == 1
            and ($credential[0].uuid | type == "string" and length > 0)
            and ($credential[0].token | type == "string" and length > 0)
          then .server.connections.forgejo += ($credential[0] | {uuid, token})
          else error("runner credentials require nonempty uuid and token strings") end
        ' ${baseConfig} > /run/forgejo-runner/config.json
      '';
      serviceConfig = {
        User = user;
        Group = user;
        WorkingDirectory = stateDir;
        RuntimeDirectory = "forgejo-runner";
        RuntimeDirectoryMode = "0700";
        LoadCredential = [ "connection:${cfg.credentialsFile}" ];
        ExecStart = "${lib.getExe pkgs.forgejo-runner} daemon --config /run/forgejo-runner/config.json";
        Restart = "on-failure";
        RestartSec = 10;
        TimeoutStopSec = "90s";
        UMask = "0077";
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ReadWritePaths = [ stateDir ];
        MemoryMax = "512M";
      };
    };
  };
}
