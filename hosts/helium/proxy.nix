{ config, ... }:
let
  paperless = config.services.paperless;
in
{
  # Paperless gets its own Tailscale node rather than a slot on one of Helium's
  # existing listeners. `bind tailscale/paperless` below replaces this site's
  # listen addresses with a userspace node inside Caddy, so the socket exists on
  # the tailnet and on no physical interface at all — there is nothing on
  # Helium's LAN or WAN address to reach, whatever the firewall says. Helium
  # already holds 80 and 443 open for Caddy (`profiles.server`), and this vhost
  # is deliberately not served on either.
  #
  # `ephemeral false` is the departure from the plugin's global default, and it
  # matters more here than it looks. An ephemeral node is torn out of the
  # tailnet every time Caddy stops: the auth key has to still be valid on each
  # restart, which for a Tailscale key means within 90 days of when it was
  # minted, and if the previous node has not been reaped yet the new one comes
  # back as `paperless-1` — a hostname nothing is configured for. Persisting the
  # node identity to disk instead means it registers once and survives reboots.
  myNixOS.services.caddy.tailscaleNodes.paperless = ''
    ephemeral false
    state_dir /var/lib/caddy/tailscale/paperless
  '';

  services.caddy.virtualHosts.${paperless.domain}.extraConfig = ''
    bind tailscale/paperless

    # Without this the site would inherit the global `acme_dns cloudflare` and
    # try to solve a DNS-01 challenge for a `.ts.net` name in a Cloudflare zone
    # we do not own, which cannot succeed. Certificates for tailnet names come
    # from Tailscale itself, which the plugin fetches over the node's LocalAPI.
    # This requires HTTPS certificates to be enabled for the tailnet in the
    # admin console; without that the site serves nothing and Caddy logs the
    # refusal on every request.
    tls {
      get_certificate tailscale
    }

    encode zstd gzip

    # No `X-Real-IP` here, unlike the mischief.town vhosts. Those sit behind
    # Cloudflare and have to recover the client address from a header; this peer
    # is a tailnet address and is already the real one.
    #
    # Websockets need no directive either — the status endpoint at /ws/status
    # upgrades through `reverse_proxy` untouched.
    reverse_proxy ${paperless.address}:${toString paperless.port}
  '';
}
