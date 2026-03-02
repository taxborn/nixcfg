{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.node-exporter.enable = lib.mkEnableOption "prometheus node exporter";

  config = lib.mkIf config.myNixOS.services.node-exporter.enable {
    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
      config.mySnippets.mischief-town.networkMap.nodeExporter.port
    ];

    services.prometheus.exporters.node = {
      enable = true;
      port = config.mySnippets.mischief-town.networkMap.nodeExporter.port;
      enabledCollectors = [
        "systemd"
        "tcpstat"
        "conntrack"
        "diskstats"
        "entropy"
        "filefd"
        "filesystem"
        "loadavg"
        "meminfo"
        "netdev"
        "netstat"
        "stat"
        "time"
        "timex"
        "vmstat"
        "logind"
        "interrupts"
        "ksmd"
        "processes"
      ];
    };
  };
}
