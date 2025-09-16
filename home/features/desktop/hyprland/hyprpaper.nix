{ osConfig, ... }:
let
  hostname = osConfig.networking.hostName;

  wallpaper =
    if hostname == "uranium" then
      "/home/taxborn/Media/Photos/Wallpapers/mandelbrot_gap_magenta.png"
    else if hostname == "tungsten" then
      "/home/taxborn/Media/Photos/Wallpapers/autumn.jpg"
    else
      "";
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
