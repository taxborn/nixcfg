{
  imports = [
    ./dunst.nix
    ./hyprland.nix
    ./hyprpaper.nix
    ./waybar.nix
  ];

  services.gnome-keyring.enable = true;

  xresources.properties = {
    "Xcursor.size" = 24;
    "Xft.dpi" = 172;
  };

  programs.wofi.enable = true;
}
