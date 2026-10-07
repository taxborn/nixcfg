{
  config,
  lib,
  self,
  ...
}:
let
  cfg = config.myNixOS.profiles.server;
in
{
  options.myNixOS.profiles.server.enable = lib.mkEnableOption "common server configuration";

  config = lib.mkIf cfg.enable {
    home-manager.users.taxborn.imports = [ self.homeModules.profile-server ];

    myNixOS = {
      base.enable = true;
      services = {
        caddy.enable = true;
        fail2ban.enable = true;
      };
    };
  };
}
