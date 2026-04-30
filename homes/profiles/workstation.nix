{ pkgs, ... }:
{
  imports = [
    ./default.nix
  ];

  config = {
    xdg = {
      enable = true;
      userDirs.setSessionVariables = true;
    };

    home.packages = with pkgs; [
      bitwarden-desktop
      discord
      obsidian
      spotify
      vlc
    ];

    programs = {
      feh.enable = true;
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

    myHome = {
      profiles.defaultApps.enable = true;
      desktop.hyprland.enable = true;
      programs = {
        firefox.enable = true;
        ghostty.enable = true;
        yubikey.enable = true;
        zed-editor.enable = true;
      };
    };
  };
}
