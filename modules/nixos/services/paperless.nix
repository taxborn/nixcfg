{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.paperless;
  networkMap = config.mySnippets.biscuits-at.networkMap;
in
{
  options.myNixOS.services.paperless.enable = lib.mkEnableOption "Paperless-ngx document archive";

  config = lib.mkIf cfg.enable {
    age.secrets.paperless.file = "${self}/secrets/paperless.age";

    services.paperless = {
      enable = true;

      # PAPERLESS_ADMIN_PASSWORD and PAPERLESS_EMAIL_HOST_PASSWORD. Neither can
      # go in `settings`: those render to a unit file in the nix store, which is
      # world-readable. The admin password is load-bearing on first start —
      # `manage_superuser` only runs when it is set, so without this file the
      # instance comes up with no account to log into.
      environmentFile = config.age.secrets.paperless.path;

      # PostgreSQL rather than the default SQLite, and this is the moment to
      # decide: paperless migrates between engines only through a full
      # document export and re-import. Its own docs call SQLite the option for
      # trying things out. Helium's backup client dumps the cluster — see
      # hosts/helium/default.nix, without which the archive holds a torn copy
      # of a running database.
      database.createLocally = true;

      # `domain` is not just a link in emails: the NixOS module turns it into
      # PAPERLESS_URL, which becomes the CSRF trusted origin and the allowed
      # Host header. A request arriving under any other name is refused, which
      # is what makes reaching this over Helium's tailnet address alone fail.
      inherit (networkMap.paperless) domain port;

      # PAPERLESS_OCR_LANGUAGE is deliberately unset. Its default is already
      # `eng`, but the NixOS module reads the *presence* of the setting as a
      # request to rebuild tesseract with only the named languages — so
      # spelling out the default swaps a cached binary for a local build of
      # tesseract, ocrmypdf, and paperless itself. Set it only to actually add
      # a language.
      settings = {
        # Where a password reset lands. Deliberately the mailbox rather than
        # `infra@`, which is a sending identity.
        PAPERLESS_ADMIN_MAIL = "hello@taxborn.com";

        # Fastmail as a smarthost, the same relay Forgejo, Vaultwarden and the
        # PDS use. Port 465 is implicit TLS, not STARTTLS — USE_TLS is the
        # STARTTLS knob and setting both is a Django configuration error.
        #
        # The login is the account the app password belongs to; the sender is
        # the apex address the zone's SPF record and DKIM CNAMEs cover. Sending
        # as anything under a subdomain means unauthenticated mail.
        PAPERLESS_EMAIL_HOST = "smtp.fastmail.com";
        PAPERLESS_EMAIL_PORT = 465;
        PAPERLESS_EMAIL_HOST_USER = "hello@taxborn.com";
        PAPERLESS_EMAIL_FROM = "infra@biscuits.at";
        PAPERLESS_EMAIL_USE_SSL = true;
      };
    };
  };
}
