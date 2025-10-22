{ config, ... }:
let
  domain = "vw.mischief.town";
in
{
  services = {
    vaultwarden = {
      enable = true;
      config = {
        DOMAIN = "https://${domain}";
        SIGNUPS_ALLOWED = true;
        ROCKET_ADDRESS = "127.0.0.1";
        ROCKET_PORT = 8222;
        ROCKET_LOG = "critical";
      };
    };
  };

  services.caddy = {
    virtualHosts.${domain}.extraConfig = ''
      reverse_proxy localhost:${toString config.services.vaultwarden.config.ROCKET_PORT}
    '';
  };
}
