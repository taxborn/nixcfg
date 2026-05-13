{
  self,
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.glance.enable = lib.mkEnableOption "glance";

  config = lib.mkIf config.myNixOS.services.glance.enable {
    age.secrets.glance.file = "${self.inputs.secrets}/glance/secrets.age";

    services.glance = {
      enable = true;
      environmentFile = config.age.secrets.glance.path;
      settings = {
        auth = {
          secret-key = "\${GLANCE_SECRET_KEY}";
          users.taxborn.password-hash = "\${GLANCE_TAXBORN_PASSWORD_HASH}";
        };
        server = {
          port = config.mySnippets.mischief-town.networkMap.glance.port;
          proxied = true;
        };
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
            columns = [
              {
                size = "full";
                widgets = [
                  {
                    type = "search";
                    search-engine = "kagi";
                    autofocus = true;
                  }
                  {
                    type = "monitor";
                    cache = "1m";
                    title = "Public Services";
                    sites = [
                      {
                        title = "Forgejo";
                        url = "https://${config.mySnippets.mischief-town.networkMap.forgejo.domain}";
                        icon = "si:forgejo";
                      }
                      {
                        title = "Vaultwarden";
                        url = "https://${config.mySnippets.mischief-town.networkMap.vaultwarden.domain}";
                        icon = "si:bitwarden";
                      }
                      {
                        title = "PDS";
                        url = "https://${config.mySnippets.mischief-town.networkMap.pds.domain}";
                        icon = "si:bluesky";
                      }
                    ];
                  }
                  {
                    type = "monitor";
                    cache = "1m";
                    title = "Internal Services";
                    sites = [
                      {
                        title = "Grafana";
                        url = "https://${config.mySnippets.mischief-town.networkMap.grafana.domain}";
                        icon = "si:grafana";
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
