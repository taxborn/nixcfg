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
                widgets = [ ];
              }
            ];
          }
        ];
      };
    };
  };
}
