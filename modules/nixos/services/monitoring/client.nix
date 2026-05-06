{
  config,
  lib,
  pkgs,
  ...
}:
let
  networkMap = config.mySnippets.mischief-town.networkMap;
  argonIP = networkMap.tailscaleIPs.argon;
  hostIP = networkMap.tailscaleIPs.${config.networking.hostName};
  hostname = config.networking.hostName;
  alloyConfig = pkgs.writeText "alloy-config.alloy" ''
    loki.write "default" {
      endpoint {
        url = "http://${argonIP}:${toString networkMap.loki.port}/loki/api/v1/push"
      }
    }

    loki.source.journal "default" {
      forward_to    = [loki.write.default.receiver]
      relabel_rules = loki.relabel.journal.rules
      labels = {
        job  = "systemd-journal",
        host = "${hostname}",
      }
    }

    loki.relabel "journal" {
      forward_to = []
      rule {
        source_labels = ["__journal__systemd_unit"]
        target_label  = "unit"
      }
    }
  '';
in
{
  options.myNixOS.services.monitoring.client.enable = lib.mkEnableOption "monitoring client (node-exporter + alloy)";

  config = lib.mkIf config.myNixOS.services.monitoring.client.enable {
    services.prometheus.exporters.node = {
      enable = true;
      listenAddress = hostIP;
      port = networkMap.nodeExporter.port;
    };

    services.alloy = {
      enable = true;
      configPath = alloyConfig;
    };
  };
}
