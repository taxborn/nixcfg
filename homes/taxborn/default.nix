{
  config,
  pkgs,
  self,
  ...
}:
{
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

    xdg.enable = true;

    home = {
      username = "taxborn";
      homeDirectory = "/home/taxborn";
      stateVersion = "25.11";
      packages = [ ];
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
        '';
        shellAliases = {
          nix-rb = "sudo nixos-rebuild switch --flake .";
          yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
        };
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
}
