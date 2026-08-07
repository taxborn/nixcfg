{ config, ... }:
let
  grafana = config.mySnippets.mischief-town.networkMap.monitoring.grafana;
in
{
  # Argon's first vhost. Everything else it runs — Prometheus, Alertmanager, the
  # ntfy bridge — stays on loopback with no way in at all; Grafana is the one
  # piece a person needs to open in a browser.
  #
  # `bind tailscale/grafana` replaces this site's listen addresses with a
  # userspace Tailscale node inside Caddy, so the socket exists on the tailnet
  # and on none of Argon's real interfaces. This is an OVH VPS with a public
  # address, and nothing about this vhost is served on it — not by firewall
  # rule, but because there is no listener there to reach.
  #
  # `ephemeral false` and an explicit `state_dir` for the reason spelled out in
  # hosts/helium/proxy.nix: an ephemeral node is torn out of the tailnet every
  # time Caddy stops, needs a still-valid auth key on each restart, and comes
  # back as `grafana-1` if the previous one has not been reaped — a name nothing
  # is bookmarked at.
  myNixOS.services.caddy.tailscaleNodes.grafana = ''
    ephemeral false
    state_dir /var/lib/caddy/tailscale/grafana
  '';

  services.caddy.virtualHosts.${grafana.domain}.extraConfig = ''
    bind tailscale/grafana

    # Required, and not inherited from anywhere useful. Without it the site
    # picks up the global `acme_dns cloudflare` and tries to solve DNS-01 for a
    # `.ts.net` name in a Cloudflare zone we do not own, which cannot succeed.
    # Certificates for tailnet names come from Tailscale over the node's
    # LocalAPI, which needs HTTPS certificates enabled for the tailnet in the
    # admin console.
    tls {
      get_certificate tailscale
    }

    encode zstd gzip

    # No `X-Real-IP`, unlike the mischief.town vhosts on Carbon: this peer is a
    # tailnet address and is already the real one. Grafana's live-tailing and
    # alerting streams upgrade through `reverse_proxy` untouched.
    reverse_proxy 127.0.0.1:${toString grafana.port}
  '';
}
