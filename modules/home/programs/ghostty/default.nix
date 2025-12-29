{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.ghostty.enable = lib.mkEnableOption "ghostty terminal emulator";

  config = lib.mkIf config.myHome.programs.ghostty.enable {
    programs.ghostty = {
      enable = true;

      settings = {
        # gtk-single-instance = true;
        # quit-after-last-window-closed = false;
        theme = "Adwaita Dark";
        # gtk-titlebar = false;
        window-padding-x = 6;
        window-padding-y = 4;
      };
    };
  };
}
