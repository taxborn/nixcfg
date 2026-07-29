{
  config,
  lib,
  ...
}:
{
  options.myNixOS.profiles.server.enable = lib.mkEnableOption "common server configuration";

  config = lib.mkIf config.myNixOS.profiles.server.enable {
    myNixOS = {
      base.enable = true;
      services = {
        caddy.enable = true;
        fail2ban = {
          enable = true;
          enableCaddyJail = true;
        };
      };
    };
  };
}
