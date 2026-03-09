{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.desktop.dwl.enable = lib.mkEnableOption "dwl desktop environment";

  config = lib.mkIf config.myHome.desktop.dwl.enable {
    home.packages = [ pkgs.dwlb ];

    services.gnome-keyring.enable = true;

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-wlr ];
      config.common.default = "wlr";
    };

    myHome = {
      desktop.enable = true;
      programs.rofi.enable = true;
      services.mako.enable = true;
    };
  };
}
