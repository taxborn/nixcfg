# minecraft service module

Manages Minecraft server instances as systemd services under `myNixOS.services.minecraft.servers`.

## deploying

After a `nixos-rebuild switch`, each enabled server starts automatically (controlled by `autoStart`, default `true`). On first deploy the services won't exist yet, so there's no restart needed — they start fresh.

```bash
just deploy argon   # or carbon, helium-01
```

## managing services

Each server becomes a systemd service named `minecraft-<name>`.

```bash
# Status
systemctl status minecraft-mavs

# Start / stop / restart
systemctl start minecraft-mavs
systemctl stop minecraft-mavs        # sends 'stop' to the server gracefully
systemctl restart minecraft-mavs
```

Stopping sends `stop` to the server's stdin pipe and waits up to `stopTimeout` seconds (default 30) for a clean shutdown before systemd kills the process.

## sending console commands

The server's stdin is a named pipe at `/run/minecraft-<name>/stdin.fifo`. Write any command to it:

```bash
echo "say hello world" > /run/minecraft-mavs/stdin.fifo
echo "list" > /run/minecraft-mavs/stdin.fifo
echo "op taxborn" > /run/minecraft-mavs/stdin.fifo
```

There is no interactive TTY — this is intentional so that stdout goes to the journal rather than a terminal session.

## checking logs

### on the host (journalctl)

```bash
# Follow live
journalctl -u minecraft-mavs -f

# Last 100 lines
journalctl -u minecraft-mavs -n 100

# Since last boot
journalctl -u minecraft-mavs -b
```

### in grafana / loki

Promtail ships all systemd journal logs to Loki, labelled by unit name. Use these LogQL queries in Grafana:

```logql
{unit="minecraft-mavs.service"}
{unit="minecraft-tbd.service"}
{unit="minecraft-mick-n-b.service"}
```

Filter further:

```logql
# Player join/leave events
{unit="minecraft-mavs.service"} |= "joined the game"

# Errors only
{unit="minecraft-mavs.service"} |= "ERROR"

# Chat messages
{unit="minecraft-mavs.service"} |= "<"
```

## configuration reference

```nix
myNixOS.services.minecraft.servers = {
  my-server = {
    enable = true;

    # required
    directory = "/home/taxborn/public/my-server";

    # optional — defaults shown
    port = 25565;              # must be unique per host
    jvmMemory = "2G";          # sets both -Xms and -Xmx
    jvmMaxMemory = null;       # set to override -Xmx separately
    extraJvmArgs = [];         # e.g. Aikar's flags
    jar = null;                # set to generate java command from options
    startCommand = null;       # fully custom command, overrides jar and start.sh
    jdkPackage = pkgs.jdk21_headless;
    user = "taxborn";
    group = "users";
    autoStart = true;
    openFirewall = true;
    stopTimeout = 30;          # seconds
  };
};
```

### start command resolution

1. `startCommand` — used as-is if set
2. `jar` — generates `java -Xms... -Xmx... [extraJvmArgs] -jar <jar> nogui`
3. fallback — runs `./start.sh` from the server directory

### adding aikar's flags

```nix
jar = "paper-1.21.4.jar";
jvmMemory = "6G";
extraJvmArgs = [
  "-XX:+UseG1GC"
  "-XX:+ParallelRefProcEnabled"
  "-XX:MaxGCPauseMillis=200"
  "-XX:+UnlockExperimentalVMOptions"
  "-XX:+DisableExplicitGC"
  "-XX:+AlwaysPreTouch"
  "-XX:G1NewSizePercent=30"
  "-XX:G1MaxNewSizePercent=40"
  "-XX:G1HeapRegionSize=8M"
  "-XX:G1ReservePercent=20"
  "-XX:G1HeapWastePercent=5"
  "-XX:G1MixedGCCountTarget=4"
  "-XX:InitiatingHeapOccupancyPercent=15"
  "-XX:G1MixedGCLiveThresholdPercent=90"
  "-XX:G1RSetUpdatingPauseTimePercent=5"
  "-XX:SurvivorRatio=32"
  "-XX:+PerfDisableSharedMem"
  "-XX:MaxTenuringThreshold=1"
];
```
