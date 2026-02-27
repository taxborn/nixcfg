{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.glance.enable = lib.mkEnableOption "glance";

  config = lib.mkIf config.myNixOS.services.glance.enable {
    services.glance = {
      enable = true;
      settings = {
        server.port = config.mySnippets.mischief-town.networkMap.glance.port;
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
                    title = "Public Services";
                    sites = [
                      {
                        title = "Forgejo";
                        url = "https://${config.mySnippets.mischief-town.networkMap.forgejo.vHost}";
                        icon = "si:forgejo";
                      }
                      {
                        title = "Vaultwarden";
                        url = "https://${config.mySnippets.mischief-town.networkMap.vaultwarden.vHost}";
                        icon = "si:bitwarden";
                      }
                      {
                        title = "PDS";
                        url = "https://${config.mySnippets.mischief-town.networkMap.pds.vHost}";
                        icon = "si:bluesky";
                      }
                      {
                        title = "Tangled Knot";
                        url = "https://${config.mySnippets.mischief-town.networkMap.tangled-knot.vHost}";
                        icon = "si:git";
                      }
                    ];
                  }
                  {
                    type = "monitor";
                    cache = "1m";
                    title = "Internal Services";
                    sites = [
                      {
                        title = "Immich";
                        url = "https://immich.${config.mySnippets.tailnet.name}";
                        icon = "si:immich";
                      }
                      {
                        title = "Paperless";
                        url = "https://paperless.${config.mySnippets.tailnet.name}";
                        icon = "si:paperlessngx";
                      }
                      {
                        title = "Copyparty";
                        url = "https://copyparty.${config.mySnippets.tailnet.name}";
                        icon = "si:files";
                      }
                      {
                        title = "Grafana";
                        url = "https://grafana.${config.mySnippets.tailnet.name}";
                        icon = "si:grafana";
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
                      "paperless-ngx/paperless-ngx"
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
