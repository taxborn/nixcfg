{
  self,
  config,
  lib,
  ...
}:
{
  options.myNixOS.services.pds.enable = lib.mkEnableOption "atproto pds";

  config = lib.mkIf config.myNixOS.services.pds.enable {
    age.secrets.pds = {
      file = "${self.inputs.secrets}/pds.age";
      mode = "600";
      owner = "pds";
      group = "pds";
    };

    services.bluesky-pds = {
      enable = true;

      environmentFiles = [ config.age.secrets.pds.path ];

      settings = {
        PDS_PORT = config.mySnippets.mischief-town.networkMap.pds.port;
        PDS_HOSTNAME = config.mySnippets.mischief-town.networkMap.pds.vHost;
        PDS_ADMIN_EMAIL = "atproto@mischief.town";
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
        ];
      };
    };

    services.pds-gatekeeper = {
      enable = true;

      settings = {
        GATEKEEPER_PORT = config.mySnippets.mischief-town.networkMap.pds.gatekeeperPort;

        PDS_BASE_URL = "http://127.0.0.1:${toString config.mySnippets.mischief-town.networkMap.pds.port}";
        GATEKEEPER_TRUST_PROXY = "true";

        PDS_ENV_LOCATION = config.age.secrets.pds.path;
      };
    };
  };
}
