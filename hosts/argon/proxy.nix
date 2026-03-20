{ config, ... }:
let
  net = config.mySnippets.mischief-town.networkMap;
in
{
  services.caddy.virtualHosts = {
    ${net.hash-haus.vHost}.extraConfig = ''
      encode zstd gzip
      reverse_proxy localhost:${toString net.hash-haus.port}
    '';
  };
}
