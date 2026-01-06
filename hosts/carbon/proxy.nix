{ config, ... }:
{
  services.caddy.virtualHosts = {
    "docs.mischief.town".extraConfig = ''reverse_proxy http://100.64.1.0:21594'';
    "mischief.town".extraConfig = ''
      redir https://www.mischief.town{uri} permanent
    '';
    "taxborn.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    "www.taxborn.com".extraConfig = ''
      respond "Hello, World!"
    '';
    "braxtonfair.com".extraConfig = ''
      redir https://www.braxtonfair.com{uri} permanent
    '';
    "www.braxtonfair.com".extraConfig = ''
      redir https://www.taxborn.com{uri} permanent
    '';
    "git.mischief.town".extraConfig = ''
      reverse_proxy localhost:8193
    '';
    "www.mischief.town".extraConfig = ''
      reverse_proxy localhost:${toString config.services.glance.settings.server.port}
    '';
    "vw.mischief.town".extraConfig = ''
      reverse_proxy localhost:${toString config.services.vaultwarden.config.ROCKET_PORT}
    '';
  };
}
