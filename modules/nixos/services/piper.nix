{
  config,
  pkgs,
  self,
  ...
}:
let
  networkMap = config.homelab.services;
  package = self.packages.${pkgs.stdenv.hostPlatform.system}.tealfm-piper;
in
{
  # Piper tracks the listening history it will submit to teal.fm in
  # SQLite. Dump the live database rather than archive its WAL files
  # out of step with it.
  homelab.backups.sqliteDatabases.tealfm-piper =
    if config.services.tealfm-piper.settings.DB_PATH != null then
      config.services.tealfm-piper.settings.DB_PATH
    else
      "${config.services.tealfm-piper.dataDir}/piper.db";

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

      ENABLE_SPOTIFY = true;
      ENABLE_LASTFM = false;
      ENABLE_APPLEMUSIC = false;
    };
  };
}
