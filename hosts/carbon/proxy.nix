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

    ${networkMap.pds.domain}.extraConfig = ''
      encode zstd gzip
      reverse_proxy http://localhost:${toString networkMap.pds.port}
    '';
  };
}
