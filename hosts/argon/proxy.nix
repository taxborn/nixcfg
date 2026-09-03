{ config, ... }:
let
  networkMap = config.mySnippets.biscuits-at.networkMap;
in
{
  myNixOS.services.caddy.cloudflareOnly = true;

  services.caddy.virtualHosts = {
    # Glance
    "biscuits.at".extraConfig = ''
      redir https://${networkMap.glance.domain}{uri} permanent
    '';
    ${networkMap.glance.domain}.extraConfig = ''
      reverse_proxy localhost:${toString networkMap.glance.port} {
        import client-ip
      }
    '';

    # Vaultwarden
    ${networkMap.vaultwarden.domain}.extraConfig = ''
      encode zstd gzip
      reverse_proxy localhost:${toString networkMap.vaultwarden.port} {
        import client-ip
      }
    '';

    # Forgejo
    ${networkMap.forgejo.domain}.extraConfig = ''
      encode zstd gzip

      request_body {
        max_size 2GB
      }

      reverse_proxy localhost:${toString networkMap.forgejo.port} {
        import client-ip
      }
    '';
  };
}
