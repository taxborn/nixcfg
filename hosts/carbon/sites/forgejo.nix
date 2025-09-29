{ config, ... }:

{
  services.forgejo = {
    enable = true;
    database.type = "postgres";
    lfs.enable = true;
    settings = {
      server = {
        DOMAIN = "code.taxborn.com";
        ROOT_URL = "https://${config.services.forgejo.settings.server.DOMAIN}";
        HTTP_PORT = 8193;
      };
      actions = {
        ENABLED = true;
      };
    };
  };

  services.caddy = {
    virtualHosts."code.taxborn.com".extraConfig = ''
      reverse_proxy localhost:${toString config.services.forgejo.settings.server.HTTP_PORT}
    '';
  };
}
