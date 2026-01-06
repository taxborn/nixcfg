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
          DOMAIN = "https://vw.mischief.town";
          SIGNUPS_ALLOWED = true;
          ROCKET_ADDRESS = "127.0.0.1";
          ROCKET_PORT = 8222;
          ROCKET_LOG = "critical";
        };
      };
    };
  };
}
