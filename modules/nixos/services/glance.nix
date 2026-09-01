{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.glance;
  networkMap = config.mySnippets.biscuits-at.networkMap;
in
{
  options.myNixOS.services.glance.enable = lib.mkEnableOption "glance dashboard";

  config = lib.mkIf cfg.enable {
    age.secrets.glance.file = "${self}/secrets/glance.age";

    services.glance = {
      environmentFile = config.age.secrets.glance.path;
      enable = true;
      settings = {
        auth = {
          secret-key = "\${GLANCE_SECRET_KEY}";
          users.taxborn.password = "\${GLANCE_USER_PASSWORD}";
        };
        server = {
          port = config.mySnippets.biscuits-at.networkMap.glance.port;
        };
        theme = {
          # HSL values
          background-color = "240 21 15";
          contrast-multiplier = 1.2;
          primary-color = "267 84 81";
          positive-color = "115 54 76";
          negative-color = "343 81 75";
        };
        pages = [
          {
            name = "Home";
            head-widgets = [
              {
                type = "search";
                search-engine = "kagi";
                autofocus = true;
              }
            ];
            columns = [
              {
                size = "full";
                widgets = [
                  {
                    type = "bookmarks";
                    groups = [
                      {
                        name = "Entertainment";
                        color = "217 92 76";
                        links = [
                          {
                            title = "Netflix";
                            url = "https://www.netflix.com/";
                          }
                          {
                            title = "HBO Max";
                            url = "https://www.hbomax.com/";
                          }
                          {
                            title = "Peacock";
                            url = "https://www.peacocktv.com/";
                          }
                          {
                            title = "YouTube";
                            url = "https://www.youtube.com/";
                          }
                          {
                            title = "YouTube TV";
                            url = "https://tv.youtube.com/";
                          }
                        ];
                      }
                      {
                        name = "Homelab Links";
                        color = "316 72 86";
                        links = [
                          {
                            title = "Glance";
                            url = "https://${networkMap.glance.domain}";
                          }
                          {
                            title = "Vaultwarden";
                            url = "https://vw.biscuits.at";
                          }
                          {
                            title = "Forgejo";
                            url = "https://git.biscuits.at";
                          }
                          {
                            title = "Paperless";
                            url = "https://docs.biscuits.at";
                          }
                          {
                            title = "Immich";
                            url = "https://i.biscuits.at";
                          }
                        ];
                      }
                    ];
                  }
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
                    type = "calendar";
                    first-day-of-week = "sunday";
                  }
                  {
                    type = "markets";
                    hide-header = true;
                    markets = [
                      {
                        name = "S&P 500";
                        symbol = "SPY";
                      }
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
