{
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.paperless-ngx.enable = lib.mkEnableOption "paperless-ngx";

  config = lib.mkIf config.myNixOS.services.paperless-ngx.enable {

    services.paperless = {
      enable = true;
      consumptionDirIsPublic = true;
      address = "0.0.0.0";
      settings = {
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          "desktop.ini"
        ];
        # TODO: this seems like german and english, figure out what it should
        # be for just english
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
  };
}
