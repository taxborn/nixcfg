{ config, ... }:
let
  networkMap = config.homelab.services;
in
{
  homelab.caddy.tailnetOnly = true;

  services.caddy.virtualHosts = {
    ${networkMap.paperless.domain}.extraConfig = ''
      encode zstd gzip

      import cloudflare-dns

      reverse_proxy 127.0.0.1:${toString networkMap.paperless.port}
    '';

    ${networkMap.grafana.domain}.extraConfig = ''
      encode zstd gzip

      import cloudflare-dns

      reverse_proxy 127.0.0.1:${toString networkMap.grafana.port}
    '';
  };
}
