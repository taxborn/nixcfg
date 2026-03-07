{
  pkgs,
  ...
}:
{
  imports = [
    ./default.nix
  ];

  config = {
    xdg.enable = true;

    home.packages = [ pkgs.via ];

    programs = {
      fish = {
        interactiveShellInit = ''
          set fish_greeting # Disable greeting

          set -gx GPG_TTY (tty)
          set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
          gpgconf --launch gpg-agent
          gpg-connect-agent updatestartuptty /bye > /dev/null
        '';
        shellAliases = {
          yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
        };
      };

      yazi = {
        enable = true;
        enableFishIntegration = true;
        shellWrapperName = "y";
      };
    };

    myHome = {
      programs = {
        bat.enable = true;
        eza.enable = true;
        fd.enable = true;
        fzf.enable = true;
        zoxide.enable = true;
      };
      taxborn.programs.neovim.enable = true;
    };
  };
}
