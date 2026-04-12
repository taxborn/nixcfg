{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myNixOS.services.minecraft;

  serverOpts = lib.types.submodule {
    options = {
      enable = lib.mkEnableOption "this minecraft server instance";

      directory = lib.mkOption {
        type = lib.types.str;
        description = "Absolute path to the server directory.";
        example = "/home/taxborn/public/mavs";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 25565;
        description = "TCP port the server listens on.";
      };

      jvmMemory = lib.mkOption {
        type = lib.types.str;
        default = "2G";
        description = "JVM heap size, used for both -Xms and -Xmx unless jvmMaxMemory is set.";
        example = "4G";
      };

      jvmMaxMemory = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "JVM max heap size (-Xmx). Defaults to jvmMemory if null.";
        example = "6G";
      };

      extraJvmArgs = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional JVM arguments.";
        example = [
          "-XX:+UseG1GC"
          "-XX:+ParallelRefProcEnabled"
          "-XX:MaxGCPauseMillis=200"
        ];
      };

      jar = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Server jar filename. If set, generates the start command from nix options instead of using start.sh.";
        example = "paper-1.21.4.jar";
      };

      startCommand = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Fully custom start command, run from the server directory. Overrides jar and start.sh.";
        example = "./start.sh";
      };

      jdkPackage = lib.mkOption {
        type = lib.types.package;
        default = pkgs.jdk21_headless;
        description = "JDK package to use for this server.";
      };

      user = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "User to run the server as. Defaults to a dedicated 'minecraft-<name>' system user.";
      };

      group = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Group to run the server as. Defaults to a dedicated 'minecraft-<name>' system group.";
      };

      autoStart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to start the server automatically on boot.";
      };

      openFirewall = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to open the server port in the firewall.";
      };

      stopTimeout = lib.mkOption {
        type = lib.types.int;
        default = 30;
        description = "Seconds to wait for graceful shutdown after sending 'stop' to stdin.";
      };
    };
  };

  resolveCommand =
    _name: s:
    if s.startCommand != null then
      s.startCommand
    else if s.jar != null then
      let
        xmx = if s.jvmMaxMemory != null then s.jvmMaxMemory else s.jvmMemory;
        extraArgs = lib.concatStringsSep " " s.extraJvmArgs;
      in
      "${s.jdkPackage}/bin/java -Xms${s.jvmMemory} -Xmx${xmx} ${extraArgs} -jar ${s.jar} nogui"
    else
      "./start.sh";

  mkStartScript =
    name: s:
    pkgs.writeShellScript "minecraft-${name}-start" ''
      FIFO="/run/minecraft-${name}/stdin.fifo"
      mkfifo -m 0600 "$FIFO"

      # Hold the write end open so the server doesn't receive immediate EOF
      tail -f /dev/null > "$FIFO" &
      TAIL_PID=$!
      trap "kill $TAIL_PID 2>/dev/null" EXIT

      ${resolveCommand name s} < "$FIFO"
    '';

  mkStopScript =
    name: pkgs.writeShellScript "minecraft-${name}-stop" ''
      echo "stop" > "/run/minecraft-${name}/stdin.fifo"
    '';

  enabledServers = lib.filterAttrs (_: s: s.enable) cfg.servers;

  effectiveUser = name: s: if s.user == null then "minecraft-${name}" else s.user;
  effectiveGroup = name: s: if s.group == null then "minecraft-${name}" else s.group;
in
{
  options.myNixOS.services.minecraft.servers = lib.mkOption {
    type = lib.types.attrsOf serverOpts;
    default = { };
    description = "Attrset of Minecraft server instances to manage.";
    example = {
      mavs = {
        enable = true;
        directory = "/home/taxborn/public/mavs";
        port = 25565;
        jvmMemory = "4G";
      };
    };
  };

  config = lib.mkIf (enabledServers != { }) {
    assertions =
      let
        ports = lib.mapAttrsToList (name: s: {
          inherit name;
          port = s.port;
        }) enabledServers;
        portValues = map (p: p.port) ports;
      in
      [
        {
          assertion = lib.length portValues == lib.length (lib.unique portValues);
          message = "myNixOS.services.minecraft: multiple servers configured on the same port.";
        }
      ];

    environment.systemPackages = lib.unique (lib.mapAttrsToList (_: s: s.jdkPackage) enabledServers);

    networking.firewall.allowedTCPPorts = lib.mapAttrsToList (_: s: s.port) (
      lib.filterAttrs (_: s: s.openFirewall) enabledServers
    );

    # Create a dedicated system user/group for each server that uses the default null user.
    # Note: the server directory must be owned (or group-writable) by the derived user.
    # Existing directories under /home may need: chown -R minecraft-<name> <dir>
    users.groups = lib.mapAttrs' (
      name: s: lib.nameValuePair (effectiveGroup name s) { }
    ) (lib.filterAttrs (_: s: s.group == null) enabledServers);

    users.users = lib.mapAttrs' (
      name: s:
      lib.nameValuePair (effectiveUser name s) {
        isSystemUser = true;
        group = effectiveGroup name s;
        description = "Dedicated system user for minecraft-${name} server.";
      }
    ) (lib.filterAttrs (_: s: s.user == null) enabledServers);

    systemd.services = lib.mapAttrs' (
      name: s:
      lib.nameValuePair "minecraft-${name}" {
        description = "Minecraft server: ${name}";
        wantedBy = lib.optionals s.autoStart [ "multi-user.target" ];
        after = [ "network.target" ];

        path = [
          s.jdkPackage
          pkgs.bash
          pkgs.coreutils
        ];

        serviceConfig = {
          Type = "simple";
          User = effectiveUser name s;
          Group = effectiveGroup name s;
          WorkingDirectory = s.directory;

          ExecStart = "${mkStartScript name s}";
          ExecStop = "${mkStopScript name}";

          StandardOutput = "journal";
          StandardError = "journal";
          SyslogIdentifier = "minecraft-${name}";

          RuntimeDirectory = "minecraft-${name}";
          RuntimeDirectoryMode = "0755";

          Restart = "on-failure";
          RestartSec = "10s";
          TimeoutStopSec = s.stopTimeout;

          ProtectHome = "read-only";
          ReadWritePaths = [ s.directory ];
          PrivateTmp = true;
          NoNewPrivileges = true;
        };
      }
    ) enabledServers;
  };
}
