{ config, ... }:

{
  services.glance = {
    enable = true;
    settings = {
      pages = [
        {
          name = "Home";
          columns = [
            {
              size = "small";
              widgets = [
                {
                  type = "clock";
                  hour-format = "24h";
                }
                {
                  type = "weather";
                  location = "St. Paul, Minnesota"
                }
              ];
            }
          ];
        }
      ];
    };
  };

  services.caddy = {
    virtualHosts."www.mischief.town".extraConfig = ''
      reverse_proxy localhost:${toString config.services.glance.settings.server.port}
    '';
  };
}
