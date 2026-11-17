{
  config,
  lib,
  ...
}:
let
  cfg = config.homelab.atuin;
  networkMap = config.homelab.services;
in
{
  options.homelab.atuin = {
    openRegistration = lib.mkEnableOption "new account registration";
  };

  config = {
    homelab.backups.postgresqlDumpAll = true;

    services.atuin = {
      enable = true;
      inherit (cfg) openRegistration;
      inherit (networkMap.atuin) port;
      host = "127.0.0.1";
      openFirewall = false;
    };
  };
}
