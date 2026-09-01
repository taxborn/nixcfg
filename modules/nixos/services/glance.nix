{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.glance;
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
      };
    };
  };
}
