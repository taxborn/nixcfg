{ config, ... }:
let
  # Short alias for the network map
  net = config.mySnippets.mischief-town.networkMap;

  # Helper function for simple reverse proxy to localhost
  localProxy = service: ''
    reverse_proxy localhost:${toString service.port}
  '';

  # Helper function for reverse proxy to a specific host
  remoteProxy = host: service: ''
    reverse_proxy http://${host}:${toString service.port}
  '';

  # Helper function for encoded reverse proxy with common headers
  encodedProxy = upstream: port: ''
    encode zstd gzip
    reverse_proxy ${upstream}:${toString port} {
      header_up X-Real-IP {remote_host}
      header_up X-Forwarded-For {remote_host}
      header_up X-Forwarded-Proto {scheme}
    }
  '';

  # Tailscale IP for services on another machine
  heliumTailscaleIP = "100.64.1.0";
in
{
  services.caddy.virtualHosts = {
    # Personal Website proxies
    "braxtonfair.com".extraConfig = ''
      redir https://www.braxtonfair.com{uri} permanent
    '';
    "www.braxtonfair.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    "taxborn.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    "www.taxborn.com".extraConfig = localProxy net.taxborn-com;

    # mischief.town - Main redirect
    "mischief.town".extraConfig = ''
      redir https://${net.glance.vHost}{uri} permanent
    '';

    # mischief.town - Bluesky PDS (with age assurance workarounds)
    ${net.pds.vHost}.extraConfig = ''
      reverse_proxy localhost:${toString net.pds.port}

      handle /xrpc/app.bsky.unspecced.getAgeAssuranceState {
        header content-type "application/json"
        header access-control-allow-headers "authorization,dpop,atproto-accept-labelers,atproto-proxy"
        header access-control-allow-origin "*"
        respond `{"lastInitiatedAt":"2025-07-14T14:22:43.912Z","status":"assured"}` 200
      }

      handle /xrpc/app.bsky.ageassurance.getConfig {
        header content-type "application/json"
        header access-control-allow-headers "authorization,dpop,atproto-accept-labelers,atproto-proxy"
        header access-control-allow-origin "*"
        respond `{"regions":[]}` 200
      }

      handle /xrpc/app.bsky.ageassurance.getState {
        header content-type "application/json"
        header access-control-allow-headers "authorization,dpop,atproto-accept-labelers,atproto-proxy"
        header access-control-allow-origin "*"
        respond `{"state":{"lastInitiatedAt":"2025-07-14T14:22:43.912Z","status":"assured","access":"full"},"metadata":{"accountCreatedAt":"2022-11-17T00:35:16.391Z"}}` 200
      }
    '';

    # mischief.town - Simple local proxies
    ${net.glance.vHost}.extraConfig = localProxy net.glance;
    ${net.tangled-knot.vHost}.extraConfig = localProxy net.tangled-knot;
    ${net.tangled-spindle.vHost}.extraConfig = localProxy net.tangled-spindle;

    # mischief.town - Services on Tailscale network (remote host)
    ${net.paperless.vHost}.extraConfig = remoteProxy heliumTailscaleIP net.paperless;

    ${net.forgejo.vHost}.extraConfig = ''
      encode zstd gzip

      @uploads method POST PUT
      handle @uploads {
        request_body { max_size 2GB }
      }

      reverse_proxy localhost:${toString net.forgejo.port} {
        header_up X-Real-Ip {remote_host}
      }
    '';

    ${net.vaultwarden.vHost}.extraConfig = encodedProxy "localhost" net.vaultwarden.port;

    # mischief.town - Encoded proxies with headers (Tailscale)
    ${net.immich.vHost}.extraConfig = encodedProxy "http://${heliumTailscaleIP}" net.immich.port;
    ${net.copyparty.vHost}.extraConfig = encodedProxy "http://${heliumTailscaleIP}" net.copyparty.port;
  };
}
