{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  site = config.homelab.services.braxton-is;

  root = "/srv/braxton-is";
  deployUser = "braxton-deploy";

  trigger = "${root}/.deployed";

  # The only command CI's deploy key may run.
  deploy = pkgs.writeShellApplication {
    name = "braxton-is-deploy";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.gnutar
      pkgs.gzip
    ];
    text = ''
      read -r verb sha extra <<<"''${SSH_ORIGINAL_COMMAND:-}"
      if [[ $verb != deploy || ! $sha =~ ^[0-9a-f]{40}$ || -n ''${extra:-} ]]; then
        echo "usage: deploy <40-hex revision>, tar.gz on stdin" >&2
        exit 2
      fi

      release=${root}/releases/$sha
      rm -rf "$release.tmp"
      mkdir "$release.tmp"
      tar -xzf - -C "$release.tmp" --no-same-owner --no-same-permissions

      # A truncated upload extracts without complaint. Refuse to point
      # `current` at anything that cannot start.
      if [[ ! -f $release.tmp/server/entry.mjs || ! -d $release.tmp/node_modules ]]; then
        rm -rf "$release.tmp"
        echo "release is missing server/entry.mjs or node_modules" >&2
        exit 3
      fi

      rm -rf "$release"
      mv -T "$release.tmp" "$release"

      # `ln -sfn` onto the live name is unlink then symlink, a window with no
      # `current`. Renaming a fresh link over it is atomic.
      ln -sfn "releases/$sha" ${root}/current.new
      mv -T ${root}/current.new ${root}/current

      # Rollback is repointing `current` at one of these and rewriting the
      # trigger, so keep a few.
      # shellcheck disable=SC2012
      ls -1dt ${root}/releases/*/ | tail -n +6 | xargs -r rm -rf

      # A write, not a touch. PathChanged fires on close-after-write, and
      # `touch` only changes attributes.
      echo "$sha" >${trigger}
      echo "deployed $sha"
    '';
  };
in
{
  users.groups.${deployUser} = { };
  users.users.${deployUser} = {
    isSystemUser = true;
    group = deployUser;
    home = root;
    shell = pkgs.bash;

    # `restrict` confines the deploy key to the forced command.
    openssh.authorizedKeys.keys = [
      ''command="${lib.getExe deploy}",restrict ${lib.trim (builtins.readFile "${self}/keys/braxton-is-deploy.pub")}''
    ];
  };

  systemd.tmpfiles.rules = [
    "d ${root} 0755 ${deployUser} ${deployUser} -"
    "d ${root}/releases 0755 ${deployUser} ${deployUser} -"
  ];

  homelab.backups.extraExcludes = [
    root
  ];

  systemd.services.braxton-is = {
    description = "braxton.is";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];

    unitConfig.ConditionPathExists = "${root}/current/server/entry.mjs";

    environment = {
      HOST = "127.0.0.1";
      PORT = toString site.port;

      NODE_ENV = "production";
      ASTRO_TELEMETRY_DISABLED = "1";
    };

    serviceConfig = {
      ExecStart = "${lib.getExe pkgs.nodejs_24} ${root}/current/server/entry.mjs";
      Restart = "on-failure";
      RestartSec = 5;

      DynamicUser = true;

      StateDirectory = "braxton-is";
      WorkingDirectory = "/var/lib/braxton-is";

      # V8 executes memory it writes, so Node aborts with this on.
      MemoryDenyWriteExecute = false;

      CapabilityBoundingSet = [ "" ];
      LockPersonality = true;
      NoNewPrivileges = true;
      PrivateDevices = true;
      PrivateTmp = true;
      ProtectClock = true;
      ProtectControlGroups = true;
      ProtectHome = true;
      ProtectHostname = true;
      ProtectKernelLogs = true;
      ProtectKernelModules = true;
      ProtectKernelTunables = true;
      ProtectProc = "invisible";
      ProtectSystem = "strict";
      RemoveIPC = true;
      RestrictNamespaces = true;
      RestrictRealtime = true;
      RestrictSUIDSGID = true;
      SystemCallArchitectures = "native";
      SystemCallFilter = [
        "@system-service"
        "~@privileged"
      ];
      UMask = "0077";

      # AF_NETLINK is required. See docs/services.md#braxton-is.
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
    };
  };

  systemd.paths.braxton-is-restart = {
    wantedBy = [ "multi-user.target" ];
    pathConfig.PathChanged = trigger;
  };
  systemd.services.braxton-is-restart = {
    description = "Restart braxton.is onto the newly deployed release";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl restart braxton-is.service";
    };
  };
}
