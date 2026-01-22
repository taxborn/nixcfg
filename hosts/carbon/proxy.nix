{ config, ... }:
{
  services.caddy.virtualHosts = {
    # Personal Website proxies
    "taxborn.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    "www.taxborn.com".extraConfig = ''
      reverse_proxy localhost:${toString config.mySnippets.mischief-town.networkMap.taxborn-com.port}
    '';
    "braxtonfair.com".extraConfig = ''
      redir https://www.braxtonfair.com{uri} permanent
    '';
    "www.braxtonfair.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';

    # mischief.town proxies
    "mischief.town".extraConfig = ''
      redir https://${config.mySnippets.mischief-town.networkMap.glance.vHost}{uri} permanent
    '';
    ${config.mySnippets.mischief-town.networkMap.pds.vHost}.extraConfig = ''
      import common
      reverse_proxy localhost:${toString config.mySnippets.mischief-town.networkMap.pds.port}

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
    ${config.mySnippets.mischief-town.networkMap.glance.vHost}.extraConfig = ''
      reverse_proxy localhost:${toString config.mySnippets.mischief-town.networkMap.glance.port}
    '';
    ${config.mySnippets.mischief-town.networkMap.paperless.vHost}.extraConfig =
      "reverse_proxy http://100.64.1.0:${toString config.mySnippets.mischief-town.networkMap.paperless.port}";
    ${config.mySnippets.mischief-town.networkMap.forgejo.vHost}.extraConfig = ''
      encode zstd gzip

      @uploads method POST PUT
      handle @uploads {
        request_body { max_size 2GB }
      }

      reverse_proxy localhost:${toString config.mySnippets.mischief-town.networkMap.forgejo.port}  {
        header_up X-Real-Ip {remote_host}
      }
    '';
    ${config.mySnippets.mischief-town.networkMap.vaultwarden.vHost}.extraConfig = ''
      encode zstd gzip
      reverse_proxy localhost:${toString config.mySnippets.mischief-town.networkMap.vaultwarden.port}  {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}}
      }
    '';
    ${config.mySnippets.mischief-town.networkMap.immich.vHost}.extraConfig = ''
      encode zstd gzip
      reverse_proxy http://100.64.1.0:${toString config.mySnippets.mischief-town.networkMap.immich.port}  {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}}
      }
    '';
    ${config.mySnippets.mischief-town.networkMap.copyparty.vHost}.extraConfig = ''
      encode zstd gzip
      reverse_proxy http://100.64.1.0:${toString config.mySnippets.mischief-town.networkMap.copyparty.port}  {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
      }
    '';
  };
}
