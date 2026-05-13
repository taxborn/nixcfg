{ config, ... }:
let
  networkMap = config.mySnippets.mischief-town.networkMap;
in
{
  services.caddy.virtualHosts = {
    ${networkMap.vaultwarden.domain}.extraConfig = ''
      encode zstd gzip
      reverse_proxy localhost:${toString networkMap.vaultwarden.port} {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
      }
    '';

    ${networkMap.pds.domain}.extraConfig = ''
      encode zstd gzip
      reverse_proxy http://localhost:${toString networkMap.pds.port}
    '';

    ${networkMap.forgejo.domain}.extraConfig = ''
      encode zstd gzip

      @uploads method POST PUT
      handle @uploads {
        request_body { max_size 2GB }
      }

      reverse_proxy localhost:${toString networkMap.forgejo.port} {
        header_up X-Real-Ip {remote_host}
      }
    '';

    "mischief.town".extraConfig = ''
      redir https://${networkMap.glance.domain}{uri} permanent
    '';
    ${networkMap.glance.domain}.extraConfig = ''
      reverse_proxy localhost:${toString networkMap.glance.port}
    '';
  };
}
