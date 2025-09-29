{ config, ... }:

{
  # temp
  environment.etc."paperless-admin-pass".text = "admin";
  services.paperless = {
    enable = true;
    passwordFile = "/etc/paperless-admin-pass";
    consumptionDirIsPublic = true;
    settings = {
      PAPERLESS_CONSUMER_IGNORE_PATTERN = [
        ".DS_STORE/*"
        "desktop.ini"
      ];
      PAPERLESS_OCR_LANGUAGE = "deu+eng";
      PAPERLESS_OCR_USER_ARGS = {
        optimize = 1;
        pdfa_image_compression = "lossless";
      };
      PAPERLESS_URL = "https://docs.mischief.town";
    };
    domain = "docs.mischief.town";
    port = 21594;
  };

  services.caddy = {
    virtualHosts."docs.mischief.town".extraConfig = ''
      reverse_proxy localhost:${toString config.services.paperless.port}
    '';
  };
}
