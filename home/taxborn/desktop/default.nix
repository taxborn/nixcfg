{ pkgs, ... }:

{
  imports = [
    ./waybar.nix
    ./hyprpaper.nix
  ];

  # X resources configuration
  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 172;
  };
}
