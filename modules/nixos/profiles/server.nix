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
        profiles.btrfs.enable = true;
        programs.grub.enable = true;
        services.caddy.enable = true;
      };
  };
}
