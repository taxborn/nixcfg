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
  # The node that `bind tailscale/git` below attaches to. Without this entry the
  # node still comes up, inheriting the plugin's global `ephemeral true` — which
  # is the failure the vhost's comment describes, arriving weeks later as a
  # `git-1` hostname that no runner is configured for.
  myNixOS.services.caddy.tailscaleNodes.git = ''
    ephemeral false
    state_dir /var/lib/caddy/tailscale/git
  '';

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

    # The same Forgejo, reachable only from the tailnet. Actions runners use
    # this and nothing else; see the runner module for why that one URL decides
    # the path for cloning and artifacts as well as for polling.
    #
    # It is a second vhost rather than a second listener on the one above,
    # because `bind tailscale/git` replaces this site's listen addresses with a
    # userspace Tailscale node inside Caddy. Forgejo itself stays on 127.0.0.1
    # — this adds a way in for tailnet peers without putting anything new on
    # Carbon's public address, which is the property `HTTP_ADDR` is protecting.
    #
    # `ephemeral false` and an explicit `state_dir` for the reason spelled out
    # in hosts/helium/proxy.nix: an ephemeral node is deleted from the tailnet
    # whenever Caddy stops, needs a still-valid auth key on every restart, and
    # comes back as `git-1` if the old one has not been reaped — at which point
    # every runner is pointed at a name that no longer resolves.
    ${networkMap.forgejo.tailnetDomain}.extraConfig = ''
      bind tailscale/git

      # Tailscale issues the certificate for this name over the node's
      # LocalAPI. Without this the site inherits the global `acme_dns
      # cloudflare` and tries to solve DNS-01 for a `.ts.net` name in a zone we
      # do not own, which cannot succeed.
      tls {
        get_certificate tailscale
      }

      encode zstd gzip

      # Artifact uploads come through here now, not through the public vhost,
      # so this needs the same ceiling. It is the more useful of the two: this
      # path does not cross Cloudflare, whose free tier caps a request body at
      # 100 MB regardless of what Caddy will accept.
      request_body {
        max_size 2GB
      }

      # No `X-Real-IP`: this peer is a tailnet address and is already the real
      # one, unlike the Cloudflare-fronted vhosts above.
      reverse_proxy localhost:${toString networkMap.forgejo.port}
    '';

    "mischief.town".extraConfig = ''
      redir https://${networkMap.glance.domain}{uri} permanent
    '';
    ${networkMap.glance.domain}.extraConfig = ''
      reverse_proxy localhost:${toString networkMap.glance.port}
    '';
  };
}
