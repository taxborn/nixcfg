{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.node-exporter.enable = lib.mkEnableOption "prometheus node exporter";

  config = lib.mkIf config.myNixOS.services.node-exporter.enable {
    services.prometheus.exporters.node = {
      enable = true;
      port = 9100;
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
