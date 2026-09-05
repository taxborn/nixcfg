{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.braxton-is;

  package = self.packages.${pkgs.stdenv.hostPlatform.system}.braxton-is;

  stateDir = "braxton-is";
in
{
  options.myNixOS.services.braxton-is = {
    enable = lib.mkEnableOption "the braxton.is website";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "braxton.is";
      description = ''
        Public hostname the site is served at. Read by the Caddy vhost in
        hosts/carbon/proxy.nix, and by nothing else — Astro's own `site` is
        baked in at build time over in the website repo, so the two are set
        separately and have to agree by hand.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3006;
      description = ''
        Loopback port the Node server listens on. Kept out of
        `mySnippets.biscuits-at.networkMap` because that map is scoped to
        `biscuits.at` and this site is not on it. Reserve 3006 for this site
        so moving it onto a host with the PDS does not collide with port 3003.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.braxton-is = {
      description = "braxton.is";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        # Astro's standalone adapter reads these two for its listener. Loopback
        # only, so Caddy is the sole route in.
        HOST = "127.0.0.1";
        PORT = toString cfg.port;

        NODE_ENV = "production";
        ASTRO_TELEMETRY_DISABLED = "1";
      };

      serviceConfig = {
        ExecStart = lib.getExe package;
        Restart = "on-failure";
        RestartSec = 5;

        DynamicUser = true;

        # Astro bakes its session store path into the build as `.astro/session`,
        # relative, so it resolves against whatever the working directory
        # happens to be. Pointing that at the state directory keeps it off the
        # read-only store. No route uses sessions yet, but the first one that
        # does would fail at runtime rather than at build time.
        StateDirectory = stateDir;
        WorkingDirectory = "/var/lib/${stateDir}";

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

        # No IPAddressAllow to go with these: the point of rendering
        # server-side is the XRPC calls out to atproto services, and which
        # hosts those are is a per-request property of the records being
        # resolved.
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

    # No `services.backups.client` entry, on purpose rather than by omission.
    # There is nothing here to carry: no database, and the state directory holds
    # only sessions, which are expendable by construction. The site itself is
    # reproducible from the revision pinned in flake.lock.
  };
}
