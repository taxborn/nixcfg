{ lib, config, ... }:
{
  options.myHome.programs.nnn.enable = lib.mkEnableOption "nnn" // { default = true; };

  config = lib.mkIf config.myHome.programs.nnn.enable {
    programs.nnn.enable = true;

    programs.fish = lib.mkIf config.programs.fish.enable {
      functions.fish_user_key_bindings.body = ''
        bind \co 'commandline -r n; commandline -f execute'
      '';

      functions.n = {
        wraps = "nnn";
        description = "nnn with cd on quit";
        body = ''
          if test -n "$NNNLVL" -a "$NNNLVL" -ge 1
            echo "nnn is already running"
            return
          end

          if test -n "$XDG_CONFIG_HOME"
            set -x NNN_TMPFILE "$XDG_CONFIG_HOME/nnn/.lastd"
          else
            set -x NNN_TMPFILE "$HOME/.config/nnn/.lastd"
          end

          command nnn $argv

          if test -e $NNN_TMPFILE
            source $NNN_TMPFILE
            rm -- $NNN_TMPFILE
          end
        '';
      };
    };
  };
}
