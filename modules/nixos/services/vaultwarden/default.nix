{
  config,
  lib,
  ...
}:
let
  networkMap = config.mySnippets.mischief-town.networkMap;
in
{
  options.myNixOS.services.vaultwarden.enable = lib.mkEnableOption "vaultwarden server";

  config = lib.mkIf config.myNixOS.services.vaultwarden.enable {
    services.vaultwarden = {
      enable = true;
      config = {
        DOMAIN = "https://${networkMap.vaultwarden.domain}";
        ROCKET_PORT = networkMap.vaultwarden.port;
        ROCKET_ADDRESS = "127.0.0.1";

        # SIGNUPS_ALLOWED = false;
        # SIGNUPS_VERIFY = true; # Enable once resend is going again

        SHOW_PASSWORD_HINT = false;

        LOG_LEVEL = "warn";
        EXTENDED_LOGGING = true;
        USE_SYS_LOG = true;
      };
    };
  };
}
