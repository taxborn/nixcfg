{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myHome.programs.screenshot;

  screenshot = pkgs.writeShellApplication {
    name = "screenshot";
    runtimeInputs = with pkgs; [
      coreutils
      grim
      hyprland # hyprctl, to resolve which monitor holds focus
      jq
      libnotify
      satty
      slurp
      wl-clipboard
    ];
    text = ''
      mode="''${1:-}"
      dir="${cfg.directory}"

      case "$mode" in
          region | monitor) ;;
          *)
              echo "usage: screenshot <region|monitor>" >&2
              exit 2
              ;;
      esac

      # Resolve the target before opening the pipeline. slurp exits non-zero
      # when the selection is cancelled with Escape, and inside a pipeline that
      # would only end the subshell -- satty would still start, on empty stdin.
      if [ "$mode" = region ]; then
          target="$(slurp)" || exit 0
      else
          # `grim -o` wants a connector name, and hyprctl is the only thing that
          # knows which of DP-3 / HDMI-A-1 / eDP-1 currently has focus.
          target="$(hyprctl monitors -j | jq -r 'first(.[] | select(.focused).name)')"
      fi

      capture() {
          if [ "$mode" = region ]; then
              grim -g "$target" -
          else
              grim -o "$target" -
          fi
      }

      mkdir -p "$dir"
      file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

      # grim writes the PNG to stdout and satty reads it from stdin, so a
      # discarded shot never touches disk. Enter saves to $file and copies;
      # Escape leaves with nothing written.
      capture | satty \
          --filename - \
          --output-filename "$file" \
          --copy-command wl-copy \
          --actions-on-enter save-to-file,save-to-clipboard,exit \
          --actions-on-escape exit

      if [ -f "$file" ]; then
          notify-send --app-name screenshot "Screenshot saved" "$file"
      fi
    '';
  };
in
{
  options.myHome.programs.screenshot = {
    enable = lib.mkEnableOption "grim/slurp screen capture annotated through satty";

    directory = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.userDirs.pictures}/screenshots";
      defaultText = lib.literalExpression ''"''${config.xdg.userDirs.pictures}/screenshots"'';
      description = "Directory saved screenshots are written to.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ screenshot ];
  };
}
