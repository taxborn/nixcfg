{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.taxborn-com;

  package = self.packages.${pkgs.stdenv.hostPlatform.system}.taxborn-com;

  stateDir = "taxborn-com";
in
{
  options.myNixOS.services.taxborn-com = {
    enable = lib.mkEnableOption "the taxborn.com website";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "www.taxborn.com";
      description = ''
        Public hostname the site is served at. Read by the Caddy vhost in
        hosts/carbon/proxy.nix, and by nothing else — Astro's own `site` is
        baked in at build time over in the website repo, so the two are set
        separately and have to agree by hand.
      '';
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3008;
      description = ''
        Loopback port the Node server listens on. Continues the 300x sequence
        in `mySnippets.mischief-town.networkMap` — Loki holds 3007 — without
        joining it, because that map is scoped to a domain this site is not on.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.taxborn-com = {
      description = "taxborn.com";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];

      environment = {
        # The two the standalone server reads for its listener. Bound to
        # loopback so Caddy is the only route in, as with every other service
        # on this host.
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

        # Astro's session store is a filesystem driver whose path is baked into
        # the build as `.astro/session` — relative, and so resolved against
        # whatever the process's working directory happens to be. Pointing that
        # at the state directory is what keeps it off the read-only store. No
        # route uses sessions yet; the ordering matters anyway, because the
        # first one that does would otherwise fail at runtime rather than at
        # build time.
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

        # No IP allowlist to go with these: the point of rendering server-side
        # is the XRPC calls this makes out to atproto services, and which hosts
        # those are is a per-request property of the records being resolved.
        #
        # AF_NETLINK is not padding. Astro's listen banner calls
        # `os.networkInterfaces()`, which is netlink underneath, and without it
        # every single start logs an unhandled rejection —
        # `uv_interface_addresses returned Unknown system error 97`, EAFNOSUPPORT
        # wearing a hat. The server does come up regardless, which is the
        # trap: it is a permanent ERROR line in Loki for a working service, and
        # a stream of those is how a real one gets scrolled past. glibc also
        # reaches for netlink to pick a source address in `getaddrinfo`, so
        # denying it puts a foot in the outbound DNS path this depends on.
        RestrictAddressFamilies = [
          "AF_UNIX"
          "AF_INET"
          "AF_INET6"
          "AF_NETLINK"
        ];
      };
    };

    # No `services.backups.client` entry, on purpose rather than by omission —
    # TODO.md's rule is that a service joins the backup set in the commit that
    # enables it. There is nothing here to carry: no database, and the state
    # directory holds only sessions, which are expendable by construction. The
    # site itself is reproducible from the revision pinned in flake.lock.
    #
    # Monitoring needs nothing either. `monitoring.client` is on by default from
    # base.nix, so the journal reaches Loki through Alloy, and the existing
    # `node_systemd_unit_state{state="failed"}` rule already covers this unit
    # dying.
  };
}
