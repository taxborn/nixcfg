{
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

    home.packages = with pkgs; [
      firefox
    ];

    programs = {
      zed-editor.enable = true;
      neovim = {
        enable = true;
        defaultEditor = true;
        viAlias = true;
        vimAlias = true;
      };
      ghostty.enable = true;
    };

    home.sessionVariables.NIXOS_OZONE_WL = "1";

    myHome = {
      programs = {
        hyprland.enable = true;
        yubikey.enable = true;
      };
    };
  };
}
