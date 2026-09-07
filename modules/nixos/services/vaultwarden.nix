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
