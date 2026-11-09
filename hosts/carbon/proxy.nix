{ config, ... }:
let
  inherit (config.mySnippets.biscuits-at.networkMap) spindle;
  site = config.mySnippets.biscuits-at.networkMap.braxton-is;
in
{
  # Carbon serves nothing else on 80/443. Minecraft has its own port.
  myNixOS.services.caddy.cloudflareOnly = true;

  services.caddy.virtualHosts = {
    # Tangled's spindle. It needs its own proxied DNS record pointing at
    # Carbon: the zone's wildcard lands on Argon, which holds no certificate
    # for this name, so Cloudflare would serve a 525. Log streaming is a
    # WebSocket, which reverse_proxy passes through without configuration.
    ${spindle.domain}.extraConfig = ''
      import cloudflare-mtls

      reverse_proxy 127.0.0.1:${toString spindle.port} {
        import client-ip
      }
    '';

    # `www` exists to be given up. It still needs its own DNS record and its
    # own certificate, because Caddy issues one per site address and a name
    # with no record cannot pass the ACME challenge. Without the record this
    # vhost fails issuance in a loop.
    "www.${site.domain}".extraConfig = ''
      import cloudflare-mtls

      redir https://${site.domain}{uri} permanent
    '';

    # The apex rather than `www`, matching the `site` in the Astro config.
    # `braxton.is` is a separate Cloudflare zone from `biscuits.at`, so the
    # origin-pull certificate in keys/ has to be uploaded to it too, or
    # Cloudflare presents no client certificate and every request is a 525.
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
