{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myNixOS.services.immich.enable = lib.mkEnableOption "glance";

  config = lib.mkIf config.myNixOS.services.immich.enable {
    services.immich = {
      enable = true;
      host = "0.0.0.0";
      accelerationDevices = null;
      port = config.mySnippets.mischief-town.networkMap.immich.port;
      settings = {
        server.externalDomain = "https://${config.mySnippets.mischief-town.networkMap.immich.vHost}";
        storageTemplate = {
          enabled = true;
          hashVerificationEnabled = true;
          template = "{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}";
        };
      };
    };

    users.users.immich.extraGroups = [
      "video"
      "render"
    ];

    hardware.graphics = {
      enable = true;
      extraPackages = [ pkgs.intel-media-driver ];
    };
  };
}
