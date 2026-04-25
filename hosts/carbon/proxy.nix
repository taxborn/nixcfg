{ config, ... }:
let
  # Short alias for the network map
  net = config.mySnippets.mischief-town.networkMap;

  # Helper function for simple reverse proxy to localhost
  localProxy = service: ''
    reverse_proxy localhost:${toString service.port}
  '';

  # Helper function for encoded reverse proxy with common headers
  encodedProxy = upstream: port: ''
    encode zstd gzip
    reverse_proxy ${upstream}:${toString port} {
      header_up X-Real-IP {remote_host}
      header_up X-Forwarded-For {remote_host}
    }
  '';
in
{
  services.caddy.virtualHosts = {
    # Personal Website proxies
    "http://braxtonfair.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    "http://www.braxtonfair.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    "taxborn.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    "www.taxborn.com".extraConfig = ''
      header {
        Strict-Transport-Security "max-age=63072000; includeSubDomains; preload"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "camera=(), microphone=(), geolocation=(), payment=(), usb=(), interest-cohort=()"
      }
      reverse_proxy localhost:${toString net.taxborn-com.port}
    '';

    # mischief.town - Main redirect
    "mischief.town".extraConfig = ''
      redir https://${net.glance.vHost}{uri} permanent
    '';

    # mischief.town - Bluesky PDS
    ${net.pds.vHost}.extraConfig = ''
      encode zstd gzip

      reverse_proxy http://localhost:${toString net.pds.port}
    '';

    # mischief.town - Simple local proxies
    ${net.glance.vHost}.extraConfig = localProxy net.glance;

    ${net.forgejo.vHost}.extraConfig = ''
      encode zstd gzip

      @uploads method POST PUT
      handle @uploads {
        request_body { max_size 2GB }
      }

      reverse_proxy localhost:${toString net.forgejo.port} {
        header_up X-Real-Ip {remote_host}
      }
    '';

    ${net.vaultwarden.vHost}.extraConfig = encodedProxy "localhost" net.vaultwarden.port;
  };
}
