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
    # The vault is a SQLite file under /var/lib/vaultwarden, so being inside
    # the backed-up `/var/lib` is not enough: archiving the live file, or its
    # `-wal` and `-shm` companions, at different moments takes a torn pair. The
    # dump goes through SQLite and sees one snapshot. The path is the
    # nixpkgs module's data folder plus Vaultwarden's default database name,
    # and `backupDir` stays null because borgmatic does this job instead.
    myNixOS.services.backups.client.sqliteDatabases.vaultwarden =
      lib.mkIf config.myNixOS.services.backups.client.enable "/var/lib/vaultwarden/db.sqlite3";

    age.secrets.vaultwarden.file = "${self}/secrets/vaultwarden.age";

    services.vaultwarden = {
      # `config` renders to a vaultwarden.env in the nix store, which is
      # world-readable, so the SMTP login and anything else secret arrives
      # through here instead.
      environmentFile = config.age.secrets.vaultwarden.path;
      enable = true;
      config = {
        DOMAIN = "https://${networkMap.vaultwarden.domain}";
        ROCKET_PORT = networkMap.vaultwarden.port;
        # Loopback, so Caddy is the only route in. This read an explicit
        # 0.0.0.0 until f1bdfff, when the closed firewall rather than the bind
        # address was all that kept the vault off Argon's public IP.
        ROCKET_ADDRESS = "127.0.0.1";

        SIGNUPS_ALLOWED = false;
        SIGNUPS_VERIFY = true;
        SHOW_PASSWORD_HINT = false;
        INVITATIONS_ALLOWED = true;

        # Port 465 is implicit TLS, which is what `force_tls` selects.
        # `starttls` is the value for 587 and is wrong here. SMTP_USERNAME and
        # SMTP_PASSWORD come from the environment file.
        #
        # The sender is the apex address, which is what the zone's SPF record
        # and DKIM CNAMEs cover. They do not descend, so sending as anything
        # under a subdomain means unauthenticated mail.
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
