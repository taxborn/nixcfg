{ config, ... }:
let
  networkMap = config.mySnippets.mischief-town.networkMap;
in
{
  services.caddy.virtualHosts = {
    ${networkMap.grafana.domain}.extraConfig = ''
      bind tailscale/grafana
      reverse_proxy localhost:${toString networkMap.grafana.port}
    '';
  };
}
