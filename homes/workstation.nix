{
  config,
  lib,
  osConfig,
  pkgs,
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
          set -gx GPG_TTY (tty)
          set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
          gpgconf --launch gpg-agent
          gpg-connect-agent updatestartuptty /bye > /dev/null
        '';
        shellAliases = {
          yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
        };
      };
    };

    home.packages = with pkgs; [ ];

    myHome = {
      programs = {
        yubikey.enable = true;
      };
    };
  };
}
