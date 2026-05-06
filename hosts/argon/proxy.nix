{ config, ... }:
let
  networkMap = config.mySnippets.mischief-town.networkMap;
in
{
  services.caddy.virtualHosts = {
    "grafana.${config.mySnippets.tailnet.name}".extraConfig = ''
      bind tailscale/grafana
      reverse_proxy localhost:${toString networkMap.grafana.port}
    '';
  };
}
