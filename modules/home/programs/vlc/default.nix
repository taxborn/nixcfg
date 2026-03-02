{ lib, config, pkgs, ... }:
{
  options.myHome.programs.vlc.enable = lib.mkEnableOption "vlc";

  config = lib.mkIf config.myHome.programs.vlc.enable {
    home.packages = [ pkgs.vlc ];
  };
}
