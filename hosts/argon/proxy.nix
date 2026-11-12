{ config, ... }:
let
  networkMap = config.mySnippets.biscuits-at.networkMap;

  # Access log for a direct vhost, in Caddy's default JSON so Alloy can ship it
  # as-is. nixpkgs already gives every vhost an unfiltered 0600 `access-*.log`,
  # Authorization header and all, and fail2ban no longer reads any of them. The
  # direct vhosts replace theirs with this one. The mTLS vhosts keep the
  # default, since that is Cloudflare's traffic and Alloy does not ship it.
  #
  # `mode 0640` is for Alloy, which joins the `caddy` group to read these (see
  # monitoring/default.nix). The default 0600 would be a silent permission
  # error. The file name is what Alloy turns into the `vhost` label, so it has
  # to keep the `direct-<name>.log` shape. The prefix is also what keeps Alloy
  # away from the 0600 defaults.
  #
  # The filter runs before the line is written, so a credential dropped here
  # never reaches disk. Authorization and Cookie carry PDS session tokens and
  # app passwords, Set-Cookie is the response half. An OAuth callback puts a
  # one-time `code` in the query string, and `request>uri` logs all of it.
  # `remote_ip` in the output is the TCP peer. `client_ip` honours
  # X-Forwarded-For from a Cloudflare range, which anyone with a Cloudflare
  # account can send, so do not alert on it.
  accessLog = name: ''
    output file /var/log/caddy/direct-${name}.log {
      mode 0640
    }
    format filter {
      wrap json
      fields {
        request>headers>Authorization delete
        request>headers>Proxy-Authorization delete
        request>headers>Cookie delete
        resp_headers>Set-Cookie delete
        request>uri query {
          replace code REDACTED
          replace state REDACTED
          replace token REDACTED
        }
      }
    }
  '';
in
{
  myNixOS.services.caddy = {
    cloudflareOnly = true;

    directVHosts = [
      networkMap.pds.domain
      "*.${networkMap.pds.domain}"
    ];
  };

  # HTTP/3 for the direct PDS names. Caddy already listens on UDP 443; only the
  # firewall was in the way. Never narrowed to Cloudflare's ranges, matching TCP
  # 443 here, which `directVHosts` has already opened to everyone. The
  # `cloudflare-mtls` vhosts still demand a client certificate over QUIC.
  networking.firewall.allowedUDPPorts = [ 443 ];

  services.caddy.virtualHosts = {
    "biscuits.at".extraConfig = ''
      import cloudflare-mtls

      redir https://${networkMap.glance.domain}{uri} permanent
    '';
    ${networkMap.glance.domain}.extraConfig = ''
      import cloudflare-mtls

      reverse_proxy 127.0.0.1:${toString networkMap.glance.port} {
        import client-ip
      }
    '';

    # No `encode`: a subscription is a long-lived stream (SSE, JSON lines or
    # WebSocket), and compressing one buffers it until the compressor has
    # enough to flush, delaying the notification it exists to deliver.
    # Cloudflare cuts a connection idle for 100 seconds, which ntfy's 45
    # second keepalive stays well inside.
    ${networkMap.ntfy.domain}.extraConfig = ''
      import cloudflare-mtls

      reverse_proxy 127.0.0.1:${toString networkMap.ntfy.port} {
        import client-ip
      }
    '';

    # Spotify and Last.fm hand their OAuth callbacks back to a public name,
    # which is the only reason a loopback-only listener needs a vhost at all.
    ${networkMap.piper.domain}.extraConfig = ''
      import cloudflare-mtls

      encode zstd gzip

      reverse_proxy 127.0.0.1:${toString networkMap.piper.port} {
        import client-ip
      }
    '';

    ${networkMap.atuin.domain}.extraConfig = ''
      import cloudflare-mtls

      encode zstd gzip

      reverse_proxy 127.0.0.1:${toString networkMap.atuin.port} {
        import client-ip
      }
    '';

    ${networkMap.vaultwarden.domain}.extraConfig = ''
      import cloudflare-mtls

      encode zstd gzip
      reverse_proxy 127.0.0.1:${toString networkMap.vaultwarden.port} {
        import client-ip
      }
    '';

    # The atproto PDS, and every account handle issued under it. Two vhosts
    # because a handle is a further label: `pds.biscuits.at` is the server and
    # `alice.pds.biscuits.at` is an account. Caddy matches the more specific
    # site, so the wildcard only ever catches the latter.
    #
    # Both names are DNS-only records, the only ones in this zone that are;
    # every other vhost here sits behind Cloudflare's proxy. Three reasons, any
    # one of which is sufficient:
    #
    #   - The universal certificate covers `biscuits.at` and `*.biscuits.at`
    #     and stops there. A proxied `alice.pds.biscuits.at` has no edge
    #     certificate at all and dies at the handshake, which is every account
    #     on the instance.
    #   - `com.atproto.sync.subscribeRepos` is a long-lived WebSocket that
    #     relays hold open through idle periods, and the proxy times those out.
    #   - The free tier caps a request body at 100 MB. Blob uploads here are
    #     allowed up to 10 GiB.
    #
    # Going direct means Caddy sees the real peer, but not that nothing can
    # claim otherwise. `trusted_proxies` is server-wide and lists Cloudflare,
    # so a connection from inside a Cloudflare range has its X-Forwarded-For
    # believed and passed to the PDS. Anyone can send one by pointing a proxied
    # record of their own at this address, and a PDS that keys rate limits or
    # logs on that header would believe it. The `client-ip` snippet would not help, since it forwards
    # `{client_ip}`, the trusting value. `{remote_host}` is the TCP peer and
    # `header_up` replaces rather than appends, so a forged value never
    # reaches the backend.
    ${networkMap.pds.domain} = {
      logFormat = accessLog networkMap.pds.domain;

      extraConfig = ''
        encode zstd gzip

        reverse_proxy 127.0.0.1:${toString networkMap.pds.port} {
          header_up X-Forwarded-For {remote_host}
          header_up X-Real-IP {remote_host}
        }
      '';
    };

    # Let's Encrypt issues a wildcard over DNS-01 and no other challenge, so
    # this is the one vhost that cannot use the HTTP-01 the rest fall back to.
    # CF_API_TOKEN comes from Caddy's environmentFile and needs Zone:DNS:Edit
    # plus Zone:Zone:Read on this zone.
    "*.${networkMap.pds.domain}" = {
      # The default log path is derived from the site address, which here
      # contains a `*`. Leaving it gives a real file in /var/log/caddy whose
      # name is a glob metacharacter, waiting for the first person to write a
      # loop over that directory.
      logFormat = accessLog "wildcard.${networkMap.pds.domain}";

      extraConfig = ''
        encode zstd gzip

        import cloudflare-dns

        # Same as the apex above, for the same reason.
        reverse_proxy 127.0.0.1:${toString networkMap.pds.port} {
          header_up X-Forwarded-For {remote_host}
          header_up X-Real-IP {remote_host}
        }
      '';
    };

    # Tangled's knot. Proxied like the rest, which costs it pushes and LFS
    # objects over 100 MB through HTTPS. Pushes go over tailnet SSH instead.
    # No CORS headers here: the knot sets its own, and upstream warns that
    # adding them at the proxy breaks it. No `encode` either, since git packs
    # are already compressed and `/events` is a stream that spindles hold open.
    ${networkMap.knot.domain}.extraConfig = ''
      import cloudflare-mtls

      reverse_proxy 127.0.0.1:${toString networkMap.knot.port} {
        import client-ip
      }
    '';
  };
}
