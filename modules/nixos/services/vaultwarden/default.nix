{
  self,
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
    age.secrets.vaultwarden.file = "${self.inputs.secrets}/mail/vaultwarden.age";

    services.vaultwarden = {
      enable = true;
      environmentFile = config.age.secrets.vaultwarden.path;

      config = {
        DOMAIN = "https://${networkMap.vaultwarden.domain}";
        ROCKET_PORT = networkMap.vaultwarden.port;
        ROCKET_ADDRESS = "127.0.0.1";

        SIGNUPS_ALLOWED = false;
        SIGNUPS_VERIFY = true;
        SHOW_PASSWORD_HINT = false;
        INVITATIONS_ALLOWED = true;

        SMTP_AUTH_MECHANISM = "Login";
        SMTP_FROM = "vaultwarden@mischief.town";
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
