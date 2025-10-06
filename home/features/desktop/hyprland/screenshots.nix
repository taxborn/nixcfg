{ pkgs, ... }:
{
  home.packages = with pkgs; [
    grim # Screenshot utility for wayland
    slurp # Select region for screenshots
    wl-clipboard # Wayland clipboard utilities
    libnotify # For notifications
  ];

  # Create screenshot directory
  home.file."Media/Photos/Screenshots/.keep".text = "";

  # Full screen screenshot script
  home.file.".local/bin/screenshot-full" = {
    text = ''
      #!/bin/sh
      # Full screen screenshot
      SCREENSHOT_DIR="$HOME/Media/Photos/Screenshots"
      FILENAME="screenshot-$(date +%Y%m%d_%H%M%S).png"
      FILEPATH="$SCREENSHOT_DIR/$FILENAME"

      mkdir -p "$SCREENSHOT_DIR"

      if grim "$FILEPATH"; then
        wl-copy < "$FILEPATH"
        notify-send "Screenshot" "Full screen captured and copied to clipboard" -i "$FILEPATH" -t 3000
        echo "$FILEPATH"
      else
        notify-send "Screenshot" "Failed to capture screenshot" -u critical -t 3000
        exit 1
      fi
    '';
    executable = true;
  };

  # Region screenshot script
  home.file.".local/bin/screenshot-region" = {
    text = ''
      #!/bin/sh
      # Region screenshot with selection
      SCREENSHOT_DIR="$HOME/Media/Photos/Screenshots"
      FILENAME="screenshot-$(date +%Y%m%d_%H%M%S).png"
      FILEPATH="$SCREENSHOT_DIR/$FILENAME"

      mkdir -p "$SCREENSHOT_DIR"

      # Use slurp to select area, then grim to capture
      AREA=$(slurp -d -c '#ff0000ff' -b '#ffffff20' -s '#00000000')

      if [ -n "$AREA" ]; then
        if grim -g "$AREA" "$FILEPATH"; then
          wl-copy < "$FILEPATH"
          notify-send "Screenshot" "Region captured and copied to clipboard" -i "$FILEPATH" -t 3000
          echo "$FILEPATH"
        else
          notify-send "Screenshot" "Failed to capture region screenshot" -u critical -t 3000
          exit 1
        fi
      else
        notify-send "Screenshot" "Screenshot cancelled" -t 2000
        exit 0
      fi
    '';
    executable = true;
  };
}
