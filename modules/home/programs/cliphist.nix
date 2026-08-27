{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myHome.programs.cliphist;

  picker = pkgs.writeShellApplication {
    name = "clipboard-history";
    runtimeInputs = with pkgs; [
      cliphist
      wl-clipboard
      wofi
    ];
    text = ''
      # `cliphist list` emits "<id>\t<preview>" per entry, and `decode` maps a
      # chosen line back to the stored bytes by that id -- so entries wofi
      # cannot render faithfully (multi-line text, images) still paste intact.
      selection="$(cliphist list | wofi --dmenu --prompt 'Clipboard')" || exit 0

      if [ -z "$selection" ]; then
          exit 0
      fi

      printf '%s' "$selection" | cliphist decode | wl-copy
    '';
  };
in
{
  options.myHome.programs.cliphist.enable =
    lib.mkEnableOption "clipboard history with a wofi picker";

  config = lib.mkIf cfg.enable {
    # Runs a wl-paste watcher per MIME class; wl-clipboard alone only ever
    # holds the most recent copy, so without this there is nothing to page back
    # through.
    services.cliphist.enable = true;

    home.packages = [ picker ];
  };
}
