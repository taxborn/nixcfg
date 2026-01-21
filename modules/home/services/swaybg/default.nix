{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myHome.services.swaybg;

  # Script to select random wallpapers and start swaybg instances
  swaybgStart = pkgs.writeShellScript "swaybg-random-start" ''
    set -euo pipefail

    WALLPAPER_DIR="${cfg.wallpaperPath}"

    # Expand ~ if present
    WALLPAPER_DIR="''${WALLPAPER_DIR/#\~/$HOME}"

    # Kill any existing swaybg instances
    ${pkgs.procps}/bin/pkill -x swaybg 2>/dev/null || true
    sleep 0.5

    # Ensure the wallpaper directory exists
    if [ ! -d "$WALLPAPER_DIR" ]; then
      echo "Wallpaper directory does not exist: $WALLPAPER_DIR"
      exit 1
    fi

    # Get list of image files
    mapfile -t WALLPAPERS < <(${pkgs.findutils}/bin/find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null)

    if [ ''${#WALLPAPERS[@]} -eq 0 ]; then
      echo "No wallpapers found in $WALLPAPER_DIR"
      exit 1
    fi

    # Get list of monitors from hyprctl
    mapfile -t MONITORS < <(${lib.getExe' config.wayland.windowManager.hyprland.package "hyprctl"} monitors -j | ${lib.getExe pkgs.jq} -r '.[].name')

    if [ ''${#MONITORS[@]} -eq 0 ]; then
      echo "No monitors detected"
      exit 1
    fi

    echo "Found ''${#MONITORS[@]} monitor(s) and ''${#WALLPAPERS[@]} wallpaper(s)"

    # Start swaybg for each monitor with a random wallpaper
    for MONITOR in "''${MONITORS[@]}"; do
      # Select a random wallpaper
      RANDOM_INDEX=$((RANDOM % ''${#WALLPAPERS[@]}))
      WALLPAPER="''${WALLPAPERS[$RANDOM_INDEX]}"

      echo "Setting wallpaper for $MONITOR: $WALLPAPER"

      # Start swaybg for this monitor
      ${lib.getExe pkgs.swaybg} -o "$MONITOR" -i "$WALLPAPER" -m fill &
    done

    echo "Wallpapers set successfully"

    # Wait for all background processes
    wait
  '';
in
{
  options.myHome.services.swaybg = {
    enable = lib.mkEnableOption "random wallpaper daemon using swaybg";

    wallpaperPath = lib.mkOption {
      type = lib.types.str;
      default = "~/media/photos/wallpapers";
      description = "Path to directory containing wallpapers";
    };
  };

  config = lib.mkIf config.myHome.services.swaybg.enable {
    home.packages = [
      pkgs.swaybg
      pkgs.jq
    ];

    systemd.user.services.swaybg-random = {
      Unit = {
        Description = "Random wallpaper daemon using swaybg";
        After = [
          "graphical-session.target"
          "hyprland-session.target"
        ];
        PartOf = "graphical-session.target";
        BindsTo = lib.optional config.wayland.windowManager.hyprland.enable "hyprland-session.target";
      };

      Service = {
        Type = "simple";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 1";
        ExecStart = "${swaybgStart}";
        Restart = "on-failure";
        RestartSec = 5;
      };

      Install.WantedBy = lib.optional config.wayland.windowManager.hyprland.enable "hyprland-session.target";
    };
  };
}
