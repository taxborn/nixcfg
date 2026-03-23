{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.programs.yubikey.enable = lib.mkEnableOption "yubikey";

  config = lib.mkIf config.myHome.programs.yubikey.enable {
    home.packages = [ pkgs.yubikey-manager ];
  };
}
