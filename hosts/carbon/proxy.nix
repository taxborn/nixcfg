{ config, ... }:
let
  networkMap = config.mySnippets.mischief-town.networkMap;
in
{
  services.caddy.virtualHosts = {
    ${networkMap.vaultwarden.domain}.extraConfig = ''
      encode zstd gzip
      reverse_proxy localhost:${toString networkMap.vaultwarden.port} {
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
      }
    '';

    # https://gist.github.com/mary-ext/6e27b24a83838202908808ad528b3318#method-5-self-hosted-pds
    # last checked 2026-05-01
    ${networkMap.pds.domain}.extraConfig = ''
      encode zstd gzip

      handle /xrpc/app.bsky.ageassurance.getState {
        header content-type "application/json"
        header access-control-allow-headers "authorization,dpop,atproto-accept-labelers,atproto-proxy"
        header access-control-allow-origin "*"
        respond `{"state":{"lastInitiatedAt":"2025-07-14T14:22:43.912Z","status":"assured","access":"full"},"metadata":{"accountCreatedAt":"2022-11-17T00:35:16.391Z"}}` 200
      }

      reverse_proxy http://localhost:${toString networkMap.pds.port}
    '';
  };
}
