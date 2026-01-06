{ config, ... }:
{
  services.caddy.virtualHosts = {
    # Personal Website proxies
    "taxborn.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    "www.taxborn.com".extraConfig = ''
      respond "Hello, World!"
    '';
    "braxtonfair.com".extraConfig = ''
      redir https://www.braxtonfair.com{uri} permanent
    '';
    "www.braxtonfair.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';

    # mischief.town proxies
    "mischief.town".extraConfig = ''
      redir https://www.mischief.town{uri} permanent
    '';
    "www.mischief.town".extraConfig = ''
      reverse_proxy localhost:${toString config.services.glance.settings.server.port}
    '';
    "docs.mischief.town".extraConfig = ''reverse_proxy http://100.64.1.0:21594'';
    "git.mischief.town".extraConfig = ''
      encode zstd gzip

      @uploads method POST PUT
      handle @uploads {
        request_body { max_size 2GB }
      }

      reverse_proxy localhost:8193  {
        header_up X-Real-Ip {remote_host}
      }
    '';
    "vw.mischief.town".extraConfig = ''
      encode zstd gzip
      reverse_proxy localhost:${toString config.services.vaultwarden.config.ROCKET_PORT}  {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}}
      }
    '';
  };
}
