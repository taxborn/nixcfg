let
  wallpaper = "/home/taxborn/nixcfg/assets/wallpapers/mandelbrot_gap_magenta.png";
in
{
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = [ "${wallpaper}" ];
      wallpaper = [ ",${wallpaper}" ];
    };
  };
}
