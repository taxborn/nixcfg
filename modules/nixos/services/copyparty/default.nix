{
  config,
  lib,
  pkgs,
  self,
  ...
}:
{
  options.myNixOS.services.copyparty.enable = lib.mkEnableOption "copyparty";

  config = lib.mkIf config.myNixOS.services.copyparty.enable {
    environment.systemPackages = [ pkgs.copyparty ];

    age.secrets.copypartyPassword = {
      file = "${self.inputs.secrets}/copyparty.age";
      owner = "copyparty";
      group = "copyparty";
    };

    services.copyparty = {
      enable = true;
      openFilesLimit = 8192;

      settings = {
        i = "0.0.0.0";
        p = config.mySnippets.mischief-town.networkMap.copyparty.port;
        rproxy = 1;
      };

      accounts = {
        taxborn.passwordFile = config.age.secrets.copypartyPassword.path;
      };

      volumes = {
        "/" = {
          path = "/srv/copyparty";
          access = {
            rw = "taxborn";
          };
          flags = {
            # enable filekeys for shareable links (4 chars long)
            fk = 4;
            # scan for new files every 60 seconds
            scan = 60;
            # enable the uploads database
            e2d = true;
            # disable multimedia parsers for safety
            d2t = true;
          };
        };
      };
    };

    # Ensure the data directory exists
    systemd.tmpfiles.rules = [
      "d /srv/copyparty 0750 copyparty copyparty -"
    ];
  };
}
