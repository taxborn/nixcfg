{ config, ... }:
let
  networkMap = config.mySnippets.mischief-town.networkMap;

  # Both vhosts here carry a login session worth stealing, and both are only
  # ever reached over TLS, so tell browsers never to try plaintext. Scoped per
  # host rather than with includeSubDomains: these are single names under
  # mischief.town, and a subdomain-wide assertion from one service would bind
  # every other name under it, including ones served elsewhere.
  hsts = ''
    header Strict-Transport-Security "max-age=31536000"
  '';

  # Caddy resolves {client_ip} through the trusted_proxies list in the caddy
  # module, so this is the visitor's address rather than the Cloudflare edge
  # the connection actually came from. X-Forwarded-For is deliberately left
  # alone: Caddy already maintains it correctly for a trusted proxy chain, and
  # overwriting it with the peer address — as this did before — replaces the
  # real client with Cloudflare in every downstream log and rate limiter.
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

      # Caddy imposes no body limit of its own, so this is a ceiling rather
      # than a relaxation — a guard on pushes and LFS uploads over HTTPS.
      # Cloudflare's plan caps request bodies at 100 MB well before this,
      # which is the real limit for anything arriving over the web domain;
      # git over SSH bypasses Cloudflare entirely and is the path for
      # anything larger.
      request_body {
        max_size 2GB
      }

      reverse_proxy localhost:${toString networkMap.forgejo.port} {
        ${realIp}
      }
    '';
  };
}
