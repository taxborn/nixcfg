{
  config,
  self,
  ...
}:
let
  networkMap = config.homelab.services;
in
{
  # Drop once nixpkgs' paperless-ngx accepts torch 2.15.
  nixpkgs.overlays = [
    (_final: prev: {
      paperless-ngx = prev.paperless-ngx.overrideAttrs (old: {
        pythonRelaxDeps = (old.pythonRelaxDeps or [ ]) ++ [ "torch" ];
      });
    })
  ];

  homelab.backups.postgresqlDumpAll = true;

  age.secrets.paperless.file = "${self}/secrets/paperless.age";

  services.paperless = {
    enable = true;

    # Required on first start, or no admin account is created.
    environmentFile = config.age.secrets.paperless.path;

    # Paperless only changes database engine through a full export and re-import.
    database.createLocally = true;

    inherit (networkMap.paperless) domain port;

    # PAPERLESS_OCR_LANGUAGE stays unset. Setting it rebuilds tesseract from source.
    settings = {
      PAPERLESS_ADMIN_MAIL = config.homelab.owner.email;

      PAPERLESS_EMAIL_HOST = config.homelab.mail.host;
      PAPERLESS_EMAIL_PORT = config.homelab.mail.port;
      PAPERLESS_EMAIL_HOST_USER = config.homelab.owner.email;
      PAPERLESS_EMAIL_FROM = config.homelab.mail.from;
      PAPERLESS_EMAIL_USE_SSL = true;
    };
  };
}
