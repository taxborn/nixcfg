{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.homelab.minecraft;
  systemctl = lib.getExe' config.systemd.package "systemctl";
  unitOf = name: "minecraft-${name}.service";

  monitoring = config.homelab.monitoring;
  hostIP = config.homelab.tailscale.address;
  inherit (config.homelab.tailscale) bindOrdering;
  hostname = config.networking.hostName;
  metricsOn = hostIP != null;

  # Never a person's account. The owner is in wheel, a Nix trusted user.
  user = "minecraft";

  stateDir = "/var/lib/minecraft";

  servers = lib.mapAttrs (
    name: server:
    server
    // {
      directory = "${stateDir}/${name}";
      jar = "fabric-server-launcher.jar";
      jvmArgs = [
        "-Xmx5G"
        "-Xms5G"
        "-Dlog4j2.formatMsgNoLookups=true"
      ];
      port = 25565;
      stopTimeout = "5min";
    }
  ) cfg.servers;
  exposedServers = lib.filterAttrs (_: server: server.openFirewall) servers;

  stdinOf = name: "/run/minecraft-${name}.stdin";

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
  options.homelab.minecraft = {
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
        lib.types.submodule {
          options = {
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
          };
        }
      );
    };
  };

  config = lib.mkIf (servers != { }) {
    assertions = [
      {
        assertion = lib.elem hostname monitoring.minecraftHosts;
        message = ''
          ${hostname} runs Minecraft servers but is not in
          homelab.monitoring.minecraftHosts, so the monitoring server never
          scrapes the exporters below and the Minecraft dashboard stays empty.
        '';
      }
    ]
    # A world outside the backup paths has no backup and nothing says so.
    ++ [
      {
        assertion = lib.all (
          server: lib.any (path: lib.hasPrefix "${path}/" "${server.directory}/") config.homelab.backups.paths
        ) (lib.attrValues servers);
        message = ''
          Every homelab.minecraft server directory on ${hostname} must
          sit under one of homelab.backups.paths, or its world
          is not archived.
        '';
      }
    ];

    users.groups.${user} = { };
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      home = stateDir;
    };

    systemd.tmpfiles.rules = [
      "d ${stateDir} 0750 ${user} ${user} -"
    ]
    ++ lib.mapAttrsToList (_: server: "d ${server.directory} 0750 ${user} ${user} -") servers;

    networking.firewall =
      let
        exposed = lib.attrValues exposedServers;
      in
      {
        allowedTCPPorts = map (server: server.port) exposed;
        allowedUDPPorts = map (server: server.port) exposed;
      };

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

    services.prometheus.exporters.process = lib.mkIf metricsOn {
      enable = true;
      listenAddress = hostIP;
      port = monitoring.ports.processExporter;
      settings.process_names = lib.mapAttrsToList (name: server: {
        name = "minecraft-${name}";
        comm = [ "java" ];
        cmdline = [ ".*-jar ${lib.escapeRegex server.jar}.*" ];
      }) servers;
    };

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
    ) servers;

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

          restartIfChanged = false;

          # Without this a missing jar loops forever and never reaches failed.
          unitConfig.ConditionPathExists = "${server.directory}/${server.jar}";

          serviceConfig = {
            ExecStart = "${lib.getExe' pkgs.jdk17_headless "java"} ${lib.escapeShellArgs server.jvmArgs} -jar ${server.jar} nogui";
            ExecStop = "${stopScript name} $MAINPID";
            TimeoutStopSec = server.stopTimeout;
            Restart = "on-failure";
            RestartSec = "30s";
            User = user;
            Group = user;
            WorkingDirectory = server.directory;
            StandardInput = "socket";
            StandardOutput = "journal";
            StandardError = "journal";

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

            RestrictAddressFamilies = [
              "AF_UNIX"
              "AF_INET"
              "AF_INET6"
              "AF_NETLINK"
            ];

            # MemoryDenyWriteExecute kills the JIT. SystemCallFilter would SIGSYS on mod natives.
          };
        }
      ) servers
      // lib.optionalAttrs metricsOn {
        prometheus-process-exporter = bindOrdering;
        minecraft-exporter = lib.recursiveUpdate bindOrdering {
          description = "Minecraft status exporter";
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${lib.getExe pkgs.mc-monitor} export-for-prometheus -port ${toString monitoring.ports.minecraftExporter} -servers ${
              lib.concatMapStringsSep "," (server: "127.0.0.1:${toString server.port}") (lib.attrValues servers)
            }";
            Restart = "on-failure";
            DynamicUser = true;
            # mc-monitor binds every interface, so the unit restricts who can reach it.
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
      // {
        # Stop the servers so the archive holds an idle world. See docs/services.md#minecraft.
        borgmatic.serviceConfig = {
          ExecStartPre = map (name: "-+${systemctl} stop ${unitOf name}") (lib.attrNames servers);
          ExecStopPost = map (name: "+${systemctl} start --no-block ${unitOf name}") (lib.attrNames servers);
        };
      };
  };
}
