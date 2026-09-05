{ config, ... }:
let
  site = config.myNixOS.services.braxton-is;
in
{
  myNixOS.services.caddy.cloudflareOnly = true;

  services.caddy.virtualHosts = {
    # `www` exists to be given up. It still needs its own DNS record and its
    # own certificate, because Caddy issues one per site address and a name
    # with no record cannot pass the ACME challenge. Without the record this
    # vhost fails issuance in a loop.
    "www.${site.domain}".extraConfig = ''
      import cloudflare-mtls

      redir https://${site.domain}{uri} permanent
    '';

    # The apex rather than `www`, matching the `site` baked into the Astro
    # build. See the `domain` option in modules/nixos/services/braxton-is.nix
    # for why the two are set in separate repos and have to agree by hand.
    ${site.domain}.extraConfig = ''
      import cloudflare-mtls

      encode zstd gzip

      header Strict-Transport-Security "max-age=31536000"
      header Content-Security-Policy "frame-ancestors 'none'"
      header X-Frame-Options "DENY"

      reverse_proxy localhost:${toString site.port} {
        import client-ip
      }
    '';
  };
}
