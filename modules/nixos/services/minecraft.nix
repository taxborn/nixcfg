{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myNixOS.services.minecraft;
  systemctl = lib.getExe' config.systemd.package "systemctl";
  backupsOn = config.myNixOS.services.backups.client.enable;
  unitOf = name: "minecraft-${name}.service";
  exposedServers = lib.filterAttrs (_: server: server.openFirewall) cfg.servers;

  monitoring = config.mySnippets.monitoring;
  hostIP = config.myNixOS.services.tailscale.address;
  inherit (config.myNixOS.services.tailscale) bindOrdering;
  hostname = config.networking.hostName;
  metricsOn = config.myNixOS.services.monitoring.client.enable && hostIP != null;

  # One account for every server, and never a person's. The servers take
  # connections from the internet and load third-party mods, so whatever runs
  # them is the account an exploit lands in. They ran as `taxborn` while the
  # packs lived in that home directory. That account is in `wheel`, which
  # `programs/nix.nix` lists in `trusted-users`, and a trusted user is
  # root-equivalent. A constant and not an option, so a host cannot set it back.
  user = "minecraft";

  # Under /var/lib on purpose. It is one of the backup client's default
  # `paths`, so a world placed here is archived without the host naming it.
  stateDir = "/var/lib/minecraft";

  stdinOf = name: "/run/minecraft-${name}.stdin";

  # The console is a FIFO, so `stop` can be written by a script and by hand. The
  # unit has to outlive the write: systemd sends SIGTERM the moment ExecStop
  # returns, and a modded world takes a while to save. Waiting on the PID keeps
  # systemd from killing a server in the middle of that save. Same shape as
  # nixpkgs' `services.minecraft-server`, which this cannot reuse because it
  # models exactly one server under its own user and data directory.
  stopScript =
    name:
    pkgs.writeShellScript "minecraft-${name}-stop" ''
      echo stop > ${stdinOf name}
      while kill -0 "$1" 2> /dev/null; do
        sleep 1s
      done
    '';
in
{
  options.myNixOS.services.minecraft = {
    servers = lib.mkOption {
      default = { };
      description = ''
        Minecraft servers, each run as `minecraft-<name>.service` from an existing
        directory. Nothing here generates the server's files yet. The directory
        keeps its own `server.properties`, whitelist, mods and world.

        The unit runs the server jar directly instead of the pack's `start.sh`.
        That script waits for a keypress when `WAIT_FOR_USER_INPUT` is set, runs
        a Java version check before every start, and can download a JDK through
        jabba, none of which belongs in a unit. Its `variables.txt` stays the
        reference for the flags below.
      '';
      type = lib.types.attrsOf (
        lib.types.submodule (
          { name, ... }:
          {
            options = {
              directory = lib.mkOption {
                type = lib.types.path;
                default = "${stateDir}/${name}";
                defaultText = lib.literalExpression ''"/var/lib/minecraft/''${name}"'';
                description = ''
                  Directory holding the server jar, `world/` and `server.properties`.
                  The `minecraft` user must own everything in it. The module
                  creates the directory itself and nothing inside it.

                  It is the only path the unit can write, and `/home` is hidden
                  from the server, so a pack cannot stay in a home directory. When
                  the backup client is on, an assertion requires it to sit under
                  one of the client's `paths`.
                '';
              };
              jar = lib.mkOption {
                type = lib.types.str;
                default = "fabric-server-launcher.jar";
                description = "Launcher jar, relative to `directory`.";
              };
              jvmArgs = lib.mkOption {
                type = lib.types.listOf lib.types.str;
                default = [
                  "-Xmx5G"
                  "-Xms5G"
                  # Log4Shell (CVE-2021-44228) mitigation for pack versions whose
                  # bundled log4j predates the fix.
                  "-Dlog4j2.formatMsgNoLookups=true"
                ];
                description = "Arguments for the JVM, matching the pack's `variables.txt`.";
              };
              openFirewall = lib.mkOption {
                type = lib.types.bool;
                default = false;
                description = ''
                  Open `port` to the internet, TCP and UDP. Minecraft speaks its own
                  protocol, so Caddy cannot front it and this is a deliberate
                  exception to the loopback-only rule. UDP is for voice chat mods and
                  Bedrock-style clients. Closed by default.
                '';
              };
              port = lib.mkOption {
                type = lib.types.port;
                default = 25565;
                description = ''
                  Port the server listens on. Nothing here writes it into
                  `server.properties`, so it must match `server-port` there. Only
                  `openFirewall` reads it.
                '';
              };
              stopTimeout = lib.mkOption {
                type = lib.types.str;
                default = "5min";
                description = ''
                  How long a `stop` may take before systemd kills the server. A
                  modded world saves slowly, and a kill during the save is the
                  failure this bound exists to avoid, so it is generous.
                '';
              };
            };
          }
        )
      );
    };
  };

  config = lib.mkIf (cfg.servers != { }) {
    assertions = [
      {
        assertion = lib.elem hostname monitoring.minecraftHosts;
        message = ''
          ${hostname} runs Minecraft servers but is not in
          mySnippets.monitoring.minecraftHosts, so the monitoring server never
          scrapes the exporters below and the Minecraft dashboard stays empty.
        '';
      }
    ]
    # The borgmatic hook at the bottom stops the servers so the archive holds
    # an idle world. That is wasted on a world borg never walks, and a
    # directory outside the client's `paths` is one with no backup and nothing
    # to say so.
    ++ lib.optional backupsOn {
      assertion = lib.all (
        server:
        lib.any (
          path: lib.hasPrefix "${path}/" "${server.directory}/"
        ) config.myNixOS.services.backups.client.paths
      ) (lib.attrValues cfg.servers);
      message = ''
        Every myNixOS.services.minecraft server directory on ${hostname} must
        sit under one of myNixOS.services.backups.client.paths, or its world
        is not archived.
      '';
    };

    users.groups.${user} = { };
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      home = stateDir;
    };

    # 0750 keeps other local accounts out of the worlds and whitelists. Only
    # the directories are created. A server's files arrive by hand, and
    # `ConditionPathExists` on the unit covers the time before they do.
    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 ${user} ${user} -"
    ]
    ++ lib.mapAttrsToList (_: server: "d ${server.directory} 0750 ${user} ${user} -") cfg.servers;

    networking.firewall =
      let
        exposed = lib.attrValues exposedServers;
      in
      {
        allowedTCPPorts = map (server: server.port) exposed;
        allowedUDPPorts = map (server: server.port) exposed;
      };

    # A scanner on the public port sends a truncated handshake. Netty fails to
    # decode it, prints the stack trace to STDERR and logs the peer as
    # `lost connection: Internal Exception: ...DecoderException`. Real clients
    # that drop or time out log a different reason with no DecoderException, so
    # this line is the scanner's alone. fail2ban only needs to exist where the
    # port is exposed, and the global ignoreIP keeps the tailnet out of it.
    environment.etc = lib.mapAttrs' (
      name: _:
      lib.nameValuePair "fail2ban/filter.d/minecraft-${name}.conf" {
        text = ''
          [Definition]
          failregex = ^.*: /<ADDR>:\d+ lost connection: Internal Exception: io\.netty\.handler\.codec\.DecoderException
          ignoreregex =
        '';
      }
    ) exposedServers;

    services.fail2ban.jails = lib.mapAttrs' (
      name: server:
      lib.nameValuePair "minecraft-${name}" {
        settings = {
          enabled = true;
          filter = "minecraft-${name}";
          backend = "systemd";
          journalmatch = "_SYSTEMD_UNIT=${unitOf name}";
          port = toString server.port;
          maxretry = 3;
          findtime = "1h";
        };
      }
    ) exposedServers;

    # Heap size is no use as a memory graph: `-Xms` equals `-Xmx`, so it is flat
    # from the first second. Resident set size is what grows past it (metaspace,
    # thread stacks, mod native allocations) and what the OOM killer reads,
    # which is why process-exporter is here at all. `minecraft-exporter` below
    # covers players, latency and health.
    services.prometheus.exporters.process = lib.mkIf metricsOn {
      enable = true;
      listenAddress = hostIP;
      port = monitoring.ports.processExporter;
      settings.process_names = lib.mapAttrsToList (name: server: {
        name = "minecraft-${name}";
        comm = [ "java" ];
        cmdline = [ ".*-jar ${lib.escapeRegex server.jar}.*" ];
      }) cfg.servers;
    };

    # Owned by the service account, so writing `stop` by hand now takes
    # `sudo -u minecraft` or root.
    systemd.sockets = lib.mapAttrs' (
      name: _:
      lib.nameValuePair "minecraft-${name}" {
        bindsTo = [ (unitOf name) ];
        socketConfig = {
          ListenFIFO = stdinOf name;
          SocketMode = "0660";
          SocketUser = user;
          SocketGroup = user;
          RemoveOnStop = true;
          FlushPending = true;
        };
      }
    ) cfg.servers;

    systemd.services =
      lib.mapAttrs' (
        name: server:
        lib.nameValuePair "minecraft-${name}" {
          description = "Minecraft server ${name}";
          wantedBy = [ "multi-user.target" ];
          requires = [ "minecraft-${name}.socket" ];
          after = [
            "network-online.target"
            "minecraft-${name}.socket"
          ];
          wants = [ "network-online.target" ];

          # A switch that touches this unit would restart it and kick everyone
          # connected. The new definition lands on the next start or reboot.
          restartIfChanged = false;

          # The module creates `directory` empty, and a server's files are
          # copied in by hand. Without this a host deployed before its world
          # arrives runs java against a missing jar every thirty seconds,
          # forever: `Restart=on-failure` never gives up, so the unit never
          # reaches `failed` and nothing alerts on the loop. A skipped unit is
          # quiet for the same reason, so check `systemctl status` after
          # moving a world in.
          unitConfig.ConditionPathExists = "${server.directory}/${server.jar}";

          serviceConfig = {
            ExecStart = "${lib.getExe' pkgs.jdk17_headless "java"} ${lib.escapeShellArgs server.jvmArgs} -jar ${server.jar} nogui";
            ExecStop = "${stopScript name} $MAINPID";
            TimeoutStopSec = server.stopTimeout;
            # `stop` from the console exits 0, which `on-failure` leaves alone.
            # A crash or an OOM kill comes back on its own.
            Restart = "on-failure";
            RestartSec = "30s";
            User = user;
            Group = user;
            WorkingDirectory = server.directory;
            StandardInput = "socket";
            StandardOutput = "journal";
            StandardError = "journal";

            # The server directory is the only thing on the host this process
            # can write, and `/home` and `/root` do not exist for it. `ExecStop`
            # still reaches the console: the FIFO sits on the read-only `/run`,
            # and the kernel checks a mount's write access for regular files
            # and directories, not for a FIFO.
            ProtectSystem = "strict";
            ProtectHome = true;
            ReadWritePaths = [ server.directory ];
            UMask = "0027";

            CapabilityBoundingSet = [ "" ];
            LockPersonality = true;
            NoNewPrivileges = true;
            PrivateDevices = true;
            PrivateTmp = true;
            ProtectClock = true;
            ProtectControlGroups = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelModules = true;
            ProtectKernelTunables = true;
            ProtectProc = "invisible";
            RemoveIPC = true;
            RestrictNamespaces = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            SystemCallArchitectures = "native";

            # AF_UNIX is how glibc reaches nscd for user and host lookups.
            # AF_NETLINK is how the JVM enumerates interfaces before it binds,
            # the same call `braxton-is.nix` documents for Node.
            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
              "AF_NETLINK"
            ];

            # Two options left off on purpose. `MemoryDenyWriteExecute` kills
            # any JIT: HotSpot writes machine code into memory and then runs
            # it, so the JVM aborts at startup. `SystemCallFilter` is off
            # because mods ship their own native libraries, and a filtered
            # call is a SIGSYS in the middle of a session that no build or
            # evaluation can predict. Add one only after watching a real pack
            # run under it.
          };
        }
      ) cfg.servers
      // lib.optionalAttrs metricsOn {
        # Players, latency and health come from a status ping, the same one the
        # multiplayer menu sends, so this needs no mod and no `enable-query`.
        prometheus-process-exporter = bindOrdering;
        minecraft-exporter = lib.recursiveUpdate bindOrdering {
          description = "Minecraft status exporter";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${lib.getExe pkgs.mc-monitor} export-for-prometheus -port ${toString monitoring.ports.minecraftExporter} -servers ${
              lib.concatMapStringsSep "," (server: "127.0.0.1:${toString server.port}") (
                lib.attrValues cfg.servers
              )
            }";
            Restart = "on-failure";
            DynamicUser = true;
            # mc-monitor has no listen-address flag, so it binds every interface
            # and the unit has to do what the flag would. Loopback is the ping to
            # the server, the tailnet range is Prometheus. Nothing else gets a
            # byte in, whatever the firewall says about the public address.
            IPAddressDeny = "any";
            IPAddressAllow = [
              "localhost"
              "100.64.0.0/10"
            ];
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
          };
        };
      }
      // lib.optionalAttrs backupsOn {
        # A running world is not a consistent backup: region files are rewritten
        # while borg reads them. Stop every server for the nightly run and bring
        # them back after, so the archive holds a world that was saved and idle.
        #
        # Two traps, both on purpose. The stop is `-` prefixed so a server that
        # will not stop cannot block the backup it was stopped for. And the
        # restart is ExecStopPost rather than a Conflicts= or After= edge:
        # Conflicts= works both ways, so starting a server mid-run would stop
        # borgmatic mid-archive and leave the stale lock the backups module
        # already documents. ExecStopPost runs when the run fails too.
        #
        # `+` runs outside the unit's sandbox, which cannot reach systemd.
        # This covers the timer only. `borgmatic create` by hand does not go
        # through this unit and archives a live world.
        borgmatic.serviceConfig = {
          ExecStartPre = map (name: "-+${systemctl} stop ${unitOf name}") (lib.attrNames cfg.servers);
          ExecStopPost = map (name: "+${systemctl} start --no-block ${unitOf name}") (
            lib.attrNames cfg.servers
          );
        };
      };
  };
}
