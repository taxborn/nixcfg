{ config, ... }:
{
  imports = [
    ./default.nix
  ];

  config = {
    xdg = {
      enable = true;
      userDirs.setSessionVariables = true;
    };

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
      tmux.enable = true;
      zed-editor.enable = true;
      claude-code.enable = true;
      firefox = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
      };
    };

    myHome = {
      desktop.hyprland.enable = true;
      programs = {
        ghostty.enable = true;
        waybar.enable = true;
        wofi.enable = true;
      };
      services.mako.enable = true;
    };
  };
}
