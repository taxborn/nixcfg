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
        lib.types.submodule {
          options = {
            directory = lib.mkOption {
              type = lib.types.path;
              description = "Directory holding the server jar, `world/` and `server.properties`.";
            };
            user = lib.mkOption {
              type = lib.types.str;
              default = "taxborn";
              description = ''
                User the server runs as. It must own `directory`. The existing
                packs live in `taxborn`'s home, so that is the default until the
                data moves somewhere a service account can own.
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
      );
    };
  };

  config = lib.mkIf (cfg.servers != { }) {
    systemd.sockets = lib.mapAttrs' (
      name: server:
      lib.nameValuePair "minecraft-${name}" {
        bindsTo = [ (unitOf name) ];
        socketConfig = {
          ListenFIFO = stdinOf name;
          SocketMode = "0660";
          SocketUser = server.user;
          SocketGroup = config.users.users.${server.user}.group;
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

          serviceConfig = {
            ExecStart = "${lib.getExe' pkgs.jdk17_headless "java"} ${lib.escapeShellArgs server.jvmArgs} -jar ${server.jar} nogui";
            ExecStop = "${stopScript name} $MAINPID";
            TimeoutStopSec = server.stopTimeout;
            # `stop` from the console exits 0, which `on-failure` leaves alone.
            # A crash or an OOM kill comes back on its own.
            Restart = "on-failure";
            RestartSec = "30s";
            User = server.user;
            WorkingDirectory = server.directory;
            StandardInput = "socket";
            StandardOutput = "journal";
            StandardError = "journal";
            NoNewPrivileges = true;
            PrivateTmp = true;
          };
        }
      ) cfg.servers
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
