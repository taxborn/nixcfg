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
      settings = {
        PAPERLESS_CONSUMER_IGNORE_PATTERN = [
          ".DS_STORE/*"
          "desktop.ini"
        ];
        PAPERLESS_OCR_USER_ARGS = {
          optimize = 1;
          pdfa_image_compression = "lossless";
        };
        PAPERLESS_URL = "https://${config.mySnippets.mischief-town.networkMap.paperless.vHost}";
      };
      domain = config.mySnippets.mischief-town.networkMap.paperless.vHost;
      port = config.mySnippets.mischief-town.networkMap.paperless.port;
    };
  };
}
