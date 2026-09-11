{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myHome.desktop.niri;
in
{
  options.myHome.desktop.niri.enable = lib.mkEnableOption "Niri with Noctalia";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      noctalia
      # Niri starts this on demand for existing X11 applications, including Steam.
      xwayland-satellite
    ];

    xdg.configFile."niri/config.kdl".source = "${self}/modules/home/desktop/niri/config.kdl";
  };
}
