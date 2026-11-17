{ config, ... }:
let
  inherit (config.homelab.services) spindle;
  site = config.homelab.services.braxton-is;
in
{
  homelab.caddy.cloudflareOnly = true;

  services.caddy.virtualHosts = {
    ${spindle.domain}.extraConfig = ''
      import cloudflare-mtls

      reverse_proxy 127.0.0.1:${toString spindle.port} {
        import client-ip
      }
    '';

    "www.${site.domain}".extraConfig = ''
      import cloudflare-mtls

      redir https://${site.domain}{uri} permanent
    '';

    ${site.domain}.extraConfig = ''
      import cloudflare-mtls

      encode zstd gzip

      header Strict-Transport-Security "max-age=31536000"
      header Content-Security-Policy "frame-ancestors 'none'"
      header X-Frame-Options "DENY"

      reverse_proxy 127.0.0.1:${toString site.port} {
        import client-ip
      }
    '';
  };
}
