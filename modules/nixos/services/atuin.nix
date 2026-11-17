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
    openRegistration = lib.mkEnableOption ''
      new account registration. Off by default, because the server is reachable
      from the internet behind Cloudflare and anyone who can register can store
      data on it. Turn it on for the one deploy that creates the account, run
      `atuin register` on a client, then turn it off and deploy again
    '';
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
