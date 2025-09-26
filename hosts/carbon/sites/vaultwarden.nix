{ config, ... }:

{
  services = {
    vaultwarden = {
      enable = true;
      config = {
        DOMAIN = "https://vw.taxborn.com";
        SIGNUPS_ALLOWED = true;
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        ROCKET_LOG = "critical";
      };
    };
  };

  services.caddy = {
    virtualHosts."vw.taxborn.com".extraConfig = ''
      reverse_proxy localhost:${toString config.services.vaultwarden.config.ROCKET_PORT}
    '';
  };
}
