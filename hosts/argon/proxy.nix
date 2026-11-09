{ config, lib, ... }:
let
  networkMap = config.mySnippets.biscuits-at.networkMap;
in
{
  myNixOS.services.caddy = {
    cloudflareOnly = true;

    directVHosts = [
      networkMap.pds.domain
      "*.${networkMap.pds.domain}"
      networkMap.forgejo.sshDomain
    ];
  };

  services.caddy.virtualHosts = {
    # Git over SSH moved to the tailnet, but the zone's proxied wildcard still
    # answers for this name and Caddy holds no certificate for it, so
    # Cloudflare fails the origin handshake and serves a 525. Redirecting beats
    # leaving a hostname that only errors.
    "git.biscuits.at".extraConfig = ''
      import cloudflare-mtls

      redir https://${networkMap.forgejo.domain}{uri} permanent
    '';

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
    # Going direct means Caddy sees the real peer, so `client_ip` is already
    # correct and the `client-ip` snippet the proxied vhosts need would only
    # overwrite a good value with the same one.
    ${networkMap.pds.domain}.extraConfig = ''
      encode zstd gzip

      reverse_proxy 127.0.0.1:${toString networkMap.pds.port}
    '';

    # Let's Encrypt issues a wildcard over DNS-01 and no other challenge, so
    # this is the one vhost that cannot use the HTTP-01 the rest fall back to.
    # CF_API_TOKEN comes from Caddy's environmentFile and needs Zone:DNS:Edit
    # plus Zone:Zone:Read on this zone.
    "*.${networkMap.pds.domain}" = {
      # The default log path is derived from the site address, which here
      # contains a `*`. Leaving it gives a real file in /var/log/caddy whose
      # name is a glob metacharacter, waiting for the first person to write a
      # loop over that directory.
      logFormat = "output file /var/log/caddy/access-wildcard.${networkMap.pds.domain}.log";

      extraConfig = ''
        encode zstd gzip

        import cloudflare-dns

        reverse_proxy 127.0.0.1:${toString networkMap.pds.port}
      '';
    };

    ${networkMap.forgejo.domain}.extraConfig = ''
      import cloudflare-mtls

      encode zstd gzip

      request_body {
        max_size 2GB
      }

      reverse_proxy 127.0.0.1:${toString networkMap.forgejo.port} {
        import client-ip
      }
    '';

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

    # The same Forgejo over the tailnet, so LFS uploads skip Cloudflare's
    # 100 MB body cap. The certificate comes from tailscaled, because Let's
    # Encrypt cannot validate a `ts.net` name.
    #
    # Port 443 is open to everyone here (the PDS), and this vhost has no mTLS,
    # so the matcher is all that keeps the forge off the public address.
    ${networkMap.forgejo.sshDomain}.extraConfig = ''
      tls {
        get_certificate tailscale
      }

      @offTailnet not remote_ip ${lib.concatStringsSep " " config.mySnippets.tailnet.ranges}
      abort @offTailnet

      request_body {
        max_size 2GB
      }

      reverse_proxy 127.0.0.1:${toString networkMap.forgejo.port}
    '';
  };
}
