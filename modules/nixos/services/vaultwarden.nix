{
  config,
  self,
  ...
}:
let
  networkMap = config.homelab.services;
in
{
  homelab.backups.sqliteDatabases.vaultwarden = "/var/lib/vaultwarden/db.sqlite3";

  age.secrets.vaultwarden.file = "${self}/secrets/vaultwarden.age";

  services.vaultwarden = {
    environmentFile = config.age.secrets.vaultwarden.path;
    enable = true;
    config = {
      DOMAIN = "https://${networkMap.vaultwarden.domain}";
      ROCKET_PORT = networkMap.vaultwarden.port;
      # Loopback only. It was once 0.0.0.0, and only the firewall kept the vault private.
      ROCKET_ADDRESS = "127.0.0.1";

      SIGNUPS_ALLOWED = false;
      SIGNUPS_VERIFY = true;
      SHOW_PASSWORD_HINT = false;
      INVITATIONS_ALLOWED = true;

      SMTP_AUTH_MECHANISM = "Login";
      SMTP_FROM = config.homelab.mail.from;
      SMTP_FROM_NAME = "Vaultwarden Service";
      SMTP_HOST = config.homelab.mail.host;
      SMTP_PORT = config.homelab.mail.port;
      SMTP_SECURITY = "force_tls";

      LOG_LEVEL = "warn";
      EXTENDED_LOGGING = true;
      USE_SYS_LOG = true;
    };
  };
}
