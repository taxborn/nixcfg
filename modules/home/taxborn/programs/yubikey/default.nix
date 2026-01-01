{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.taxborn.programs.yubikey.enable = lib.mkEnableOption "yubikey";

  config = lib.mkIf config.myHome.taxborn.programs.yubikey.enable {
    home.packages = [ pkgs.yubikey-manager ];
  };
}
