{ config, ... }:

{
  services.caddy = {
    enable = true;

    virtualHosts."mischief.town".extraConfig = ''
      redir https://www.mischief.town{uri} permanent
    '';
    virtualHosts."www.mischief.town".extraConfig = ''
      reverse_proxy localhost:${config.services.glance.settings.server.port}
    '';
  };

  services.glance.enable = true;
}
