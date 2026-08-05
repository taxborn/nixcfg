{ config, ... }:
let
  networkMap = config.mySnippets.mischief-town.networkMap;
  hsts = ''
    header Strict-Transport-Security "max-age=31536000"
  '';
  realIp = ''
    header_up X-Real-IP {client_ip}
  '';
in
{
  services.caddy.virtualHosts = {
    # Vaultwarden
    ${networkMap.vaultwarden.domain}.extraConfig = ''
      encode zstd gzip
      ${hsts}
      reverse_proxy localhost:${toString networkMap.vaultwarden.port} {
        ${realIp}
      }
    '';

    # Forgejo
    ${networkMap.forgejo.domain}.extraConfig = ''
      encode zstd gzip
      ${hsts}

      request_body {
        max_size 2GB
      }

      reverse_proxy localhost:${toString networkMap.forgejo.port} {
        ${realIp}
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
