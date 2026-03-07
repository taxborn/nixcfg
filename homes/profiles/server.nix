{
  ...
}:
{
  imports = [
    ./default.nix
  ];

  config = {
    programs = {
      fish = {
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
          nix-rb = "sudo nixos-rebuild switch --flake .";
          n = "nnn -e";
        };
      };

      nnn.enable = true;
    };
  };
}
