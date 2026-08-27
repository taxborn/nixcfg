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
      coreutils
      wl-clipboard
      wofi
    ];
    text = ''
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/cliphist-thumbnails"

      # cliphist renders every non-text entry as the literal placeholder
      # "[[ binary data <size> <type> <W>x<H> ]]" -- readable, but it is all the
      # picker used to show for a screenshot. Match the image types so those
      # rows can be given the picture instead.
      image_entry='\[\[ binary data .+ (png|jpe?g|gif|bmp|webp) [0-9]+x[0-9]+ \]\]'

      mkdir -p "$cache"

      entries="$(cliphist list)"

      if [ -z "$entries" ]; then
          exit 0
      fi

      # Thumbnails are keyed by cliphist id, so drop the ones whose entry has
      # aged out of the history rather than letting the cache grow without
      # bound. cliphist ids only ever increase, so a surviving file always
      # refers to the entry it was decoded from.
      for thumb in "$cache"/*.png; do
          if [ -e "$thumb" ]; then
              id="$(basename "$thumb" .png)"

              if ! printf '%s\n' "$entries" | cut -f1 | grep -qx "$id"; then
                  rm -f "$thumb"
              fi
          fi
      done

      # An image row becomes "img:<thumbnail>:text:<line>". wofi draws the
      # thumbnail and echoes the whole string back, which the strip further
      # down turns into the original line again. Anything wofi cannot draw
      # falls through as plain text, so a failed decode still lists.
      render() {
          while IFS= read -r line; do
              if ! [[ "$line" =~ $image_entry ]]; then
                  printf '%s\n' "$line"
                  continue
              fi

              id="$(printf '%s' "$line" | cut -f1)"
              thumb="$cache/$id.png"

              if [ ! -f "$thumb" ] && ! cliphist decode "$id" >"$thumb"; then
                  rm -f "$thumb"
                  printf '%s\n' "$line"
                  continue
              fi

              printf 'img:%s:text:%s\n' "$thumb" "$line"
          done
      }

      # image_size is set here rather than in the shared wofi config, which
      # would resize the drun launcher's icons to match.
      selection="$(printf '%s\n' "$entries" | render | wofi \
          --dmenu \
          --allow-images \
          --define image_size=${toString cfg.thumbnailSize} \
          --prompt 'Clipboard')" || exit 0

      if [ -z "$selection" ]; then
          exit 0
      fi

      # Shortest-match, and a thumbnail path never contains ":text:", so this
      # removes exactly the escape wofi echoed back.
      selection="''${selection#img:*:text:}"

      # `cliphist decode` maps the line back to the stored bytes by its id
      # prefix, so entries the preview cannot represent still paste intact.
      printf '%s' "$selection" | cliphist decode | wl-copy
    '';
  };
in
{
  options.myHome.programs.cliphist = {
    enable = lib.mkEnableOption "clipboard history with a wofi picker";

    thumbnailSize = lib.mkOption {
      type = lib.types.ints.positive;
      default = 96;
      description = ''
        Pixel size of image thumbnails in the picker. wofi's own default of 32
        is too small to tell two screenshots apart.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # Runs a wl-paste watcher per MIME class; wl-clipboard alone only ever
    # holds the most recent copy, so without this there is nothing to page back
    # through.
    services.cliphist.enable = true;

    home.packages = [ picker ];
  };
}
