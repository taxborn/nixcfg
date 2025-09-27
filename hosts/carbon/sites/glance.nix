{ config, ... }:

{
  services.glance = {
    enable = true;
    settings = {
      theme = {
        background-color = "240 21 15";
        contrast-multiplier =  1.2;
        primary-color = "217 92 83";
        positive-color: 115 54 76
        negative-color: 347 70 65
      };
      pages = [
        {
          name = "Home";
          columns = [
            {
              size = "small";
              widgets = [
                {
                  type = "calendar";
                  first-day-of-week = "sunday";
                }
                {
                  type = "twitch-channels";
                  channels = [
                    "sphaerophoria"
                    "andrewrok"
                    "theprimeagen"
                  ];
                }
              ];
            }
            {
              size = "full";
              widgets = [
                {
                  type = "group";
                  widgets = [
                    {
                      type = "hacker-news";
                    }
                    {
                      type = "lobsters";
                    }
                  ];
                }
              ];
            }
            {
              size = "small";
              widgets = [
                {
                  type = "weather";
                  location = "City of Eagan";
                  units = "metric";
                  hour-format = "24h";
                }
                {
                  type = "markets";
                  markets = [
                    {
                      symbol = "SPY";
                      name = "S&P 500";
                    }
                    {
                      symbol = "TRI";
                      name = "Thomson Reuters";
                    }
                  ];
                }
                {
                  type = "releases";
                  cache = "1d";
                  repositories = [
                    "glanceapp/glance"
                    "immich-app/immich"
                    "codeburg:immich-app/immich"
                  ];
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
