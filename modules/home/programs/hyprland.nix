{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.programs.hyprland.enable = lib.mkEnableOption "hyprland window manager";

  config = lib.mkIf config.myHome.programs.hyprland.enable {
    home.packages = with pkgs; [
      wofi
      waybar
      mako
      hyprpicker
      hyprcursor
      hyprpaper
      hyprsunset
      hyprpolkitagent
    ];

    programs.hyprlock.enable = true;
    services.hypridle.enable = true;
  };
}
