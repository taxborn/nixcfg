{ config, ... }:
let
  net = config.mySnippets.mischief-town.networkMap;
  tailnet = config.mySnippets.tailnet.name;
in
{
  services.caddy.virtualHosts = {
    "grafana.${tailnet}".extraConfig = ''
      bind tailscale/grafana
      reverse_proxy localhost:${toString net.grafana.port}
    '';
    "immich.${tailnet}".extraConfig = ''
      bind tailscale/immich
      reverse_proxy localhost:${toString net.immich.port}
    '';
    "paperless.${tailnet}".extraConfig = ''
      bind tailscale/paperless
      reverse_proxy localhost:${toString net.paperless.port}
    '';
  };
}
