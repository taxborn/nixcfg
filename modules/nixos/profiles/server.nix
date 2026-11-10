{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.profiles.server;
in
{
  options.myNixOS.profiles.server.enable = lib.mkEnableOption "common server configuration";

  config = lib.mkIf cfg.enable {
    # No home profile of its own. `base` imports `profile-default`, and a
    # server wants nothing beyond it.
    myNixOS = {
      base.enable = true;
      services = {
        caddy.enable = true;
        fail2ban.enable = true;
      };
    };
  };
}
