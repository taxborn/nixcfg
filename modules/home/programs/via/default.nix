{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.myHome.programs.via.enable = lib.mkEnableOption "via";

  config = lib.mkIf config.myHome.programs.via.enable {
    home.packages = [ pkgs.via ];
  };
}
