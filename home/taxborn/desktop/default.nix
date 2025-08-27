{ pkgs, ... }:

{
  imports = [
    ./waybar.nix
    ./hyprpaper.nix
  ];

  services.dunst.enable = true;
  services.gnome-keyring.enable = true;

  # X resources configuration
  xresources.properties = {
    "Xcursor.size" = 16;
    "Xft.dpi" = 172;
  };
}
