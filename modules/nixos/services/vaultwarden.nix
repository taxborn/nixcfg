{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.vaultwarden;
  networkMap = config.mySnippets.biscuits-at.networkMap;
in
{
  options.myNixOS.services.vaultwarden.enable = lib.mkEnableOption "vaultwarden password manager";

  config = lib.mkIf cfg.enable {
    age.secrets.vaultwarden.file = "${self}/secrets/vaultwarden.age";

    services.vaultwarden = {
      environmentFile = config.age.secrets.vaultwarden.path;
      enable = true;
      config = {
        DOMAIN = "https://${networkMap.vaultwarden.domain}";
        ROCKET_PORT = networkMap.vaultwarden.port;
        ROCKET_ADDRESS = "0.0.0.0";

        SIGNUPS_ALLOWED = true;
        SIGNUPS_VERIFY = true;
        SHOW_PASSWORD_HINT = false;
        INVITATIONS_ALLOWED = true;

        SMTP_AUTH_MECHANISM = "Login";
        SMTP_FROM = "infra@biscuits.at";
        SMTP_FROM_NAME = "Vaultwarden Service";
        SMTP_HOST = "smtp.fastmail.com";
        SMTP_PORT = 465;
        SMTP_SECURITY = "force_tls";

        LOG_LEVEL = "warn";
        EXTENDED_LOGGING = true;
        USE_SYS_LOG = true;
      };
    };
  };
}
