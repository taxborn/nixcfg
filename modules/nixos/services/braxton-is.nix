{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.braxton-is;
  site = config.mySnippets.biscuits-at.networkMap.braxton-is;

  root = "/srv/braxton-is";
  deployUser = "braxton-deploy";

  # Where the forced command writes the deployed revision. The path unit below
  # watches it. Kept outside `releases/` so pruning can never touch it.
  trigger = "${root}/.deployed";

  # What CI's SSH key is allowed to run, and the only thing it is allowed to
  # run. The release arrives as a gzipped tar on stdin and the revision as the
  # one argument, so there is no rsync, no remote path to name and nothing for
  # a stolen key to do beyond putting a new release in place.
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
  options.myNixOS.services.braxton-is.enable = lib.mkEnableOption "the braxton.is website";

  config = lib.mkIf cfg.enable {
    users.groups.${deployUser} = { };
    users.users.${deployUser} = {
      isSystemUser = true;
      group = deployUser;
      home = root;
      # sshd runs a forced command through the account's shell, and the system
      # user default of nologin makes that fail with no hint in the client.
      shell = pkgs.bash;

      # `restrict` drops the pty, forwarding and agent access. The store path
      # is needed because a forced command runs without the system PATH. The
      # key lives in Forgejo's secrets for this one repository and nowhere else.
      #
      # This confines the key. It does not close a shell on 22 reachable by
      # tailnet identity, which only the tailnet ACLs can do.
      openssh.authorizedKeys.keys = [
        ''command="${lib.getExe deploy}",restrict ${lib.trim (builtins.readFile "${self}/keys/braxton-is-deploy.pub")}''
      ];
    };

    # The deploy user owns the tree and the service user only reads it, so a
    # bug in the site cannot rewrite the code it is running.
    systemd.tmpfiles.rules = [
      "d ${root} 0755 ${deployUser} ${deployUser} -"
      "d ${root}/releases 0755 ${deployUser} ${deployUser} -"
    ];

    # Releases are rebuilt by CI from the repository, and a rollback target
    # older than a few deploys is not worth archiving.
    myNixOS.services.backups.client.extraExcludes =
      lib.mkIf config.myNixOS.services.backups.client.enable
        [
          root
        ];

    systemd.services.braxton-is = {
      description = "braxton.is";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      # Nothing exists here until CI has deployed once. Without this the first
      # `just update carbon` leaves a failed unit that nothing deployed yet can
      # explain. The path unit below starts the service after the first deploy.
      unitConfig.ConditionPathExists = "${root}/current/server/entry.mjs";

      environment = {
        # Astro's standalone adapter reads these two for its listener. Loopback
        # only, so Caddy is the sole route in.
        HOST = "127.0.0.1";
        PORT = toString site.port;

        NODE_ENV = "production";
        ASTRO_TELEMETRY_DISABLED = "1";
      };

      serviceConfig = {
        # The release's `node_modules` carries prebuilt glibc binaries
        # (sharp, lightningcss, rolldown) that cannot load on NixOS, which has
        # no /lib64 loader. Harmless while nothing at runtime calls them. A
        # route that uses `astro:assets` through sharp will fail on first
        # request, not at start.
        ExecStart = "${lib.getExe pkgs.nodejs_24} ${root}/current/server/entry.mjs";
        Restart = "on-failure";
        RestartSec = 5;

        DynamicUser = true;

        # Astro bakes its session store path into the build as `.astro/session`,
        # relative, so it resolves against whatever the working directory
        # happens to be. Pointing that at the state directory keeps it off the
        # read-only release tree. No route uses sessions yet, but the first one
        # that does would fail at runtime rather than at build time.
        StateDirectory = "braxton-is";
        WorkingDirectory = "/var/lib/braxton-is";

        # Deliberately left off, and this is the one hardening option here that
        # looks free and is not: V8 compiles to memory it then executes, so
        # denying write+execute pages makes Node abort on startup rather than
        # merely narrowing what it can do.
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

        # No IPAddressAllow to go with these: which hosts a server-rendered
        # page calls out to is a per-request property, not something to pin.
        #
        # AF_NETLINK is not padding. Astro's listen banner calls
        # `os.networkInterfaces()`, netlink underneath, and without it every
        # start logs an unhandled rejection: `uv_interface_addresses returned
        # Unknown system error 97`, which is EAFNOSUPPORT. The server comes up
        # anyway, which is the trap. A permanent ERROR line on a working
        # service is how a real one gets scrolled past. glibc also uses netlink
        # to pick a source address in `getaddrinfo`, so denying it sits in the
        # outbound DNS path this depends on.
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
      };
    };

    # How a deploy becomes a restart without the deploy user holding any
    # privilege: it writes a file, and root-owned systemd reacts to that.
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
  };
}
