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
      discord
      obsidian
      spotify
    ];

    programs.fish = {
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

    myHome = {
      profiles.defaultApps.enable = true;
      desktop.hyprland.enable = true;
      programs = {
        bitwarden = {
          enable = true;
          email = "hello@taxborn.com";
          baseUrl = "https://vw.mischief.town";
        };
        firefox.enable = true;
        ghostty.enable = true;
        minecraft.enable = true;
        zed-editor.enable = true;
      };
    };
  };
}
