{ config, ... }:
let
  net = config.mySnippets.mischief-town.networkMap;
in
{
  services.caddy.virtualHosts = {
    "www.${net.hash-haus.vHost}".extraConfig = ''
      redir https://${net.hash-haus.vHost}{uri} permanent
    '';

    ${net.hash-haus.vHost}.extraConfig = ''
      encode zstd gzip
      reverse_proxy localhost:${toString net.hash-haus.port}
    '';
  };
}
