{ config, ... }:
let
  networkMap = config.mySnippets.biscuits-at.networkMap;
in
{
  services.caddy.virtualHosts = {
    "biscuits.at".extraConfig = ''
      redir https://${networkMap.glance.domain}{uri} permanent
    '';
    ${networkMap.glance.domain}.extraConfig = ''
      reverse_proxy localhost:${toString networkMap.glance.port}
    '';
  };
}
