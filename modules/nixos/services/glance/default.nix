{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.glance.enable = lib.mkEnableOption "vaultwarden";

  config = lib.mkIf config.myNixOS.services.glance.enable {
    services.glance = {
      enable = true;
      settings = {
        theme = {
          background-color = "240 21 15";
          contrast-multiplier = 1.2;
          primary-color = "217 92 83";
          positive-color = "115 54 76";
          negative-color = "347 70 65";
        };
        pages = [
          {
            name = "Home";
            center-vertically = true;
            columns = [
              {
                size = "full";
                widgets = [
                  {
                    type = "search";
                    autofocus = true;
                  }
                  {
                    type = "monitor";
                    cache = "1m";
                    title = "Services";
                    sites = [
                      {
                        title = "Vaultwarden";
                        url = "https://vw.mischief.town";
                      }
                      {
                        title = "Forgejo";
                        url = "https://git.mischief.town";
                      }
                      {
                        title = "Paperless";
                        url = "https://docs.mischief.town";
                      }
                    ];
                  }
                ];
              }
            ];
          }
          {
            name = "Info";
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
                    show-source-icon = true;
                    repositories = [
                      "glanceapp/glance"
                      "immich-app/immich"
                      "codeberg:Forgejo/forgejo"
                      "codeberg:ziglang/zig"
                    ];
                  }
                ];
              }
            ];
          }
        ];
      };
    };
  };
}
