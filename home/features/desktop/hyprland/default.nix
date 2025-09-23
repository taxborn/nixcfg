{
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.features.desktop.hyprland;
in
{
  options.features.desktop.hyprland.enable = mkEnableOption "enable hyprland";

  imports = [
    ./dunst.nix
    ./hyprland.nix
    ./hyprpaper.nix
    ./waybar.nix
  ];

  config = mkIf cfg.enable {

    services.gnome-keyring.enable = true;

    xresources.properties = {
      "Xcursor.size" = 24;
      "Xft.dpi" = 172;
    };

    programs.wofi.enable = true;
  };
}
