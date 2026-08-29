{ config, ... }:
let
  networkMap = config.mySnippets.mischief-town.networkMap;
  taxborn = config.myNixOS.services.taxborn-com;
  hsts = ''
    header Strict-Transport-Security "max-age=31536000"
  '';
  frameAncestors = ''
    header Content-Security-Policy "frame-ancestors 'none'"
    header X-Frame-Options "DENY"
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
      ${frameAncestors}
      reverse_proxy localhost:${toString networkMap.vaultwarden.port} {
        ${realIp}
      }
    '';

    # Forgejo
    ${networkMap.forgejo.domain}.extraConfig = ''
      encode zstd gzip
      ${hsts}
      ${frameAncestors}

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

    # The atproto PDS, and every account handle issued under it. Two vhosts
    # because a handle is a further label: `pds.mischief.town` is the server
    # and `alice.pds.mischief.town` is an account, and Caddy matches the more
    # specific site, so the wildcard only ever catches the latter.
    #
    # Both names are DNS-only records, the only ones in this zone that are —
    # every other vhost here sits behind Cloudflare's proxy. Three reasons, any
    # one of which is sufficient:
    #
    #   - The universal certificate covers `mischief.town` and
    #     `*.mischief.town` and stops there. A proxied
    #     `alice.pds.mischief.town` has no edge certificate at all and dies at
    #     the handshake, which is every account on the instance.
    #   - `com.atproto.sync.subscribeRepos` is a long-lived WebSocket that
    #     relays hold open through idle periods, and the proxy times those out.
    #   - The free tier caps a request body at 100 MB. Blob uploads here are
    #     allowed up to 10 GiB.
    #
    # Going direct means Caddy sees the real peer, so `client_ip` is already
    # correct and no `X-Real-IP` is needed — same as the tailnet vhost above,
    # for the opposite reason.
    ${networkMap.pds.domain}.extraConfig = ''
      encode zstd gzip
      ${hsts}
      ${frameAncestors}

      reverse_proxy localhost:${toString networkMap.pds.port}
    '';

    "*.${networkMap.pds.domain}" = {
      # Same override, same reason as `*.taxborn.com` below: the default log
      # path is derived from the site address, which here contains a `*`, and
      # the caddy-auth jail's pre-creation rule rewrites that to `wildcard`.
      # See `caddyLogName` in modules/nixos/services/fail2ban.nix.
      logFormat = "output file /var/log/caddy/access-wildcard.${networkMap.pds.domain}.log";

      extraConfig = ''
        encode zstd gzip
        ${hsts}
        ${frameAncestors}

        reverse_proxy localhost:${toString networkMap.pds.port}
      '';
    };

    "mischief.town".extraConfig = ''
      redir https://${networkMap.glance.domain}{uri} permanent
    '';
    ${networkMap.glance.domain}.extraConfig = ''
      reverse_proxy localhost:${toString networkMap.glance.port}
    '';

    # taxborn.com. The first vhost on this host outside the mischief.town zone,
    # which is why it reads its address off the service rather than out of the
    # network map. It needs nothing else the others do not: no `tls` block,
    # because a public name inherits the global `acme_dns cloudflare` correctly
    # — though the API token behind that has to carry the taxborn.com zone as
    # well, or issuance fails here and nowhere else.
    #
    # The apex is a redirect rather than a second copy of the site, mirroring
    # mischief.town above. It still needs its own DNS record: Cloudflare has to
    # reach Caddy for the redirect to be the thing that answers.
    "taxborn.com".extraConfig = ''
      redir https://${taxborn.domain}{uri} permanent
    '';
    ${taxborn.domain}.extraConfig = ''
      encode zstd gzip
      ${hsts}
      ${frameAncestors}
      reverse_proxy localhost:${toString taxborn.port} {
        ${realIp}
      }
    '';

    # Every name under taxborn.com arrives here, because the zone's wildcard
    # CNAME is proxied. Without this block such a request matches no site, dies
    # at the TLS handshake, and Cloudflare reports 525 — which reads like an
    # outage rather than a subdomain that was never meant to exist.
    #
    # It is also what makes the zone's HSTS header true. Cloudflare appends
    # `includeSubDomains; preload` to what Caddy sends, promising that every
    # name under taxborn.com speaks valid HTTPS; a handshake failure on an
    # arbitrary subdomain is that promise being false, and `preload` is the part
    # that is painful to withdraw once a browser has it.
    #
    # The certificate this needs is a wildcard, so it can only be issued over
    # DNS-01. That is already the default here via the global `acme_dns
    # cloudflare`, and the API token behind it carries the taxborn.com zone —
    # which is exactly what it did not do when this site first went up.
    #
    # Caddy matches the most specific site block, so `www` above keeps its own
    # vhost and certificate, and a future `pds.taxborn.com` will too. This only
    # catches names nothing else has claimed. 404 rather than a redirect to the
    # homepage on purpose: a redirect would turn every typo into a 200 and
    # quietly swallow a subdomain someone meant to configure.
    "*.taxborn.com" = {
      # The one vhost here that cannot take the module's default log path: it
      # derives the filename from the site address, which for this one contains
      # a `*`. `wildcard` is what the caddy-auth jail's pre-creation rule
      # rewrites that to, and the two have to agree — see `caddyLogName` in
      # modules/nixos/services/fail2ban.nix for what goes wrong when they do
      # not.
      logFormat = "output file /var/log/caddy/access-wildcard.taxborn.com.log";

      extraConfig = ''
        ${hsts}
        ${frameAncestors}
        respond 404
      '';
    };
  };
}
