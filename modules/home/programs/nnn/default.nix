{ lib, config, ... }:
{
  options.myHome.programs.nnn.enable = lib.mkEnableOption "nnn" // { default = true; };

  config = lib.mkIf config.myHome.programs.nnn.enable {
    programs.nnn.enable = true;

    programs.fish = lib.mkIf config.programs.fish.enable {
      interactiveShellInit = ''
        function nnn-cd
          set NNN_TMPFILE (mktemp)
          nnn -e $argv
          if test -s $NNN_TMPFILE
            source $NNN_TMPFILE
            rm $NNN_TMPFILE
          end
        end

        bind \co nnn-cd
      '';
      shellAliases = {
        n = "nnn -e";
      };
    };
  };
}
