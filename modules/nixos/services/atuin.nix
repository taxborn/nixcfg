{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.atuin;
  networkMap = config.mySnippets.biscuits-at.networkMap;
in
{
  options.myNixOS.services.atuin = {
    enable = lib.mkEnableOption "Atuin shell history sync server";

    openRegistration = lib.mkEnableOption ''
      new account registration. Off by default, because the server is reachable
      from the internet behind Cloudflare and anyone who can register can store
      data on it. Turn it on for the one deploy that creates the account, run
      `atuin register` on a client, then turn it off and deploy again
    '';
  };

  config = lib.mkIf cfg.enable {
    # The server's data is in postgres, in an `atuin` database the nixpkgs
    # module creates. Atuin encrypts history on the client, so what lands in
    # the dump is ciphertext. It is still the only copy a new machine can sync
    # from, so it is dumped like every other database. `pg_dumpall` covers it
    # without naming it, see the databases section of the backups README.
    myNixOS.services.backups.client.postgresqlDumpAll =
      lib.mkIf config.myNixOS.services.backups.client.enable true;

    services.atuin = {
      enable = true;
      inherit (cfg) openRegistration;
      inherit (networkMap.atuin) port;
      # Loopback, so Caddy is the only route in. This is also the module's
      # default, written out so the bind address is visible next to the port.
      host = "127.0.0.1";
      # The default firewall stance is closed, and so is this. The port is
      # never opened, only Caddy reaches it.
      openFirewall = false;
    };
  };
}
