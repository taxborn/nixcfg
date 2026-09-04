{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myNixOS.services.piper;
  networkMap = config.mySnippets.biscuits-at.networkMap;
  package = self.packages.${pkgs.stdenv.hostPlatform.system}.tealfm-piper;
in
{
  options.myNixOS.services.piper.enable = lib.mkEnableOption "Piper teal.fm music tracker";

  config = lib.mkIf cfg.enable {
    # The upstream module renders `settings` to an environment file in the Nix
    # store, so provider credentials and Piper's ATProto private key must stay
    # in agenix. The service user is created by that upstream module.
    age.secrets.piper = {
      file = "${self}/secrets/piper.age";
      owner = "tealfm-piper";
      group = "tealfm-piper";
      mode = "0400";
    };

    services.tealfm-piper = {
      enable = true;
      inherit package;
      environmentFiles = [ config.age.secrets.piper.path ];

      settings = {
        SERVER_HOST = "127.0.0.1";
        SERVER_PORT = networkMap.piper.port;
        SERVER_ROOT_URL = "https://${networkMap.piper.domain}";

        # Piper's upstream dotenv template turns all providers on. Apple Music
        # needs an additional Apple developer signing key, so keep it opt-in;
        # Spotify and Last.fm are configured through piper.age.
        ENABLE_SPOTIFY = "true";
        ENABLE_LASTFM = "true";
        ENABLE_APPLEMUSIC = "false";
      };
    };
  };
}
