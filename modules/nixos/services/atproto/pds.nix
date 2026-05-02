{
  config,
  lib,
  self,
  ...
}:
let
  networkMap = config.mySnippets.mischief-town.networkMap;
in
{
  options.myNixOS.services.pds.enable = lib.mkEnableOption "atproto pds";

  config = lib.mkIf config.myNixOS.services.pds.enable {
    age.secrets.pds = {
      file = "${self.inputs.secrets}/atproto/pds.age";
      mode = "600";
      owner = "pds";
      group = "pds";
    };

    services.bluesky-pds = {
      enable = true;
      pdsadmin.enable = true;

      environmentFiles = [ config.age.secrets.pds.path ];

      settings = {
        PDS_HOSTNAME = networkMap.pds.domain;
        PDS_OAUTH_PROVIDER_NAME = networkMap.pds.domain;
        PDS_PORT = networkMap.pds.port;
        PDS_ADMIN_EMAIL = "pds@mischief.town";
        # crawlers shamlessly stolen from
        # <https://compare.hose.cam>
        PDS_CRAWLERS = lib.concatStringsSep "," [
          "https://bsky.network"
          "https://relay.cerulea.blue"
          "https://relay.fire.hose.cam"
          "https://relay2.fire.hose.cam"
          "https://relay3.fr.hose.cam"
          "https://relay.hayescmd.net"
          "https://relay.xero.systems"
          "https://relay.upcloud.world"
          "https://relay.feeds.blue"
          "https://atproto.africa"
          "https://relay.whey.party"
        ];
      };
    };
  };
}
