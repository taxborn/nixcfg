{
  config,
  self,
  ...
}:
{
  home-manager.users.taxborn = {
    imports = [
      self.homeModules.default
    ];

    config = {
      nix = {
        inherit (config.mySnippets.nix) settings;

        gc = {
          automatic = true;
          options = "--delete-older-than 3d";
          persistent = true;
          randomizedDelaySec = "60min";
        };
      };

      home = {
        username = "taxborn";
        homeDirectory = "/home/taxborn";
        stateVersion = "25.11";
      };

      programs = {
        home-manager.enable = true;

        fish = {
          enable = true;
          interactiveShellInit = ''
            set fish_greeting # Disable greeting

            set -gx GPG_TTY (tty)
            set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
            gpgconf --launch gpg-agent
            gpg-connect-agent updatestartuptty /bye > /dev/null

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
            yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
            n = "nnn -e";
          };
        };

        nnn = {
          enable = true;
        };
      };

      myHome = {
        taxborn.programs = {
          git.enable = true;
          gpg.enable = true;
          tmux.enable = true;
          yubikey.enable = true;
        };
      };
    };
  };
}
