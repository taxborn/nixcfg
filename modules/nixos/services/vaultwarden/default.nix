{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.vaultwarden.enable = lib.mkEnableOption "vaultwarden";

  config = lib.mkIf config.myNixOS.services.vaultwarden.enable {
    services = {
      vaultwarden = {
        enable = true;
        config = {
          DOMAIN = "https://${config.mySnippets.mischief-town.networkMap.vaultwarden.vHost}";
          SIGNUPS_ALLOWED = true;
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = config.mySnippets.mischief-town.networkMap.vaultwarden.port;
          ROCKET_LOG = "critical";
        };
      };
    };
  };
}
