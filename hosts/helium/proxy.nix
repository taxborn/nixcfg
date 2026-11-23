{ config, lib, ... }:
let
  networkMap = config.homelab.services;
  inherit (config.homelab) hosts devices;
  albedoClients = [
    hosts.tungsten
    hosts.uranium
  ]
  ++ lib.attrValues devices;
in
{
  homelab.caddy.tailnetOnly = true;

  services.caddy.virtualHosts = {
    ${networkMap.albedo.domain}.extraConfig = ''
      @denied not remote_ip ${lib.concatStringsSep " " albedoClients}
      respond @denied "Forbidden" 403

      encode zstd gzip

      import cloudflare-dns

      reverse_proxy 127.0.0.1:${toString networkMap.albedo.port}
    '';

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
