{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.waybar.enable = lib.mkEnableOption "Waybar status bar";

  config = lib.mkIf config.myHome.programs.waybar.enable {
    # tbd, once I get this styled re-enable?
    catppuccin.waybar.enable = false;
    programs.waybar = {
      enable = true;
      systemd.enable = false; # Launched via Hyprland exec-once under UWSM
    };
  };
}
