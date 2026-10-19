{ lib, ... }:
let
  portType = lib.types.ints.between 1 65535;
  mkPort =
    description: default:
    lib.mkOption {
      type = portType;
      inherit default description;
    };
in
{
  options.mySnippets.monitoring = {
    server = lib.mkOption {
      type = lib.types.str;
      default = "helium";
      description = ''
        The host running Prometheus, Loki and Grafana. Every other host's Alloy
        pushes its journal to this host's tailnet address, and the monitoring
        server module asserts it is the one enabling itself.

        Not Argon, which already carries the forge, the password manager, the
        PDS and the public edge. Helium is quiet, tailnet-only and has the disk.
      '';
    };

    alwaysOn = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "argon"
        "carbon"
        "helium"
      ];
      description = ''
        Hosts where being down is a fault. They land in the `node` job and
        `InstanceDown` covers that job alone. Everything else on the tailnet is
        scraped as `node-intermittent`, because `up == 0` is a laptop's lid or
        a desktop's power button rather than an outage.
      '';
    };

    physicalDisks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "helium"
        "tungsten"
        "uranium"
      ];
      description = ''
        Hosts with disks that answer a SMART command. Decides whether
        `smartctl_exporter` runs and whether it is scraped. The OVH instances
        are left out because virtio devices report nothing, which is the same
        reason `myHardware.profiles.ovh` turns `smartd` off. The client module
        asserts the two agree.
      '';
    };

    minecraftHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "argon"
        "carbon"
      ];
      description = ''
        Hosts running `myNixOS.services.minecraft` servers. Each runs a status
        exporter and a process exporter beside them, and the monitoring server
        scrapes both. The Minecraft module asserts that a host with servers is
        listed here, since an unlisted one would export metrics nothing collects.
      '';
    };

    ports = {
      minecraftExporter = mkPort "mc-monitor's status exporter, on each Minecraft host's tailnet address." 9150;
      processExporter = mkPort "process-exporter, on each Minecraft host's tailnet address. Its upstream default." 9256;
      nodeExporter = mkPort "node_exporter, bound to each host's tailnet address." 9100;
      smartctlExporter = mkPort "smartctl_exporter, bound to each host's tailnet address." 9633;
      prometheus = mkPort "Prometheus, loopback on the server." 9090;
      alertmanager = mkPort "Alertmanager, loopback on the server." 9093;
      alertmanagerNtfy = mkPort "The Alertmanager to ntfy bridge, loopback on the server." 8111;
      loki = mkPort "Loki HTTP, bound to the server's tailnet address for remote Alloys." 3100;
      lokiGrpc = mkPort "Loki's internal gRPC ring, loopback. Pinned because 0 is advertised as-is." 9096;
    };
  };
}
