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

    home.packages = with pkgs; [
      discord
      obsidian
      spotify
      signal-desktop
    ];

    programs.zen-browser = {
      enable = true;
      nativeMessagingHosts = [ pkgs.bitwarden-desktop ];
    };

    programs.fish = {
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

    myHome = {
      taxborn.programs = {
        minecraft.enable = true;
        zed-editor.enable = true;
        zen.enable = true;
      };
      profiles.defaultApps.enable = true;
      desktop.hyprland.enable = true;
      programs = {
        cheatsheet.enable = true;
        bitwarden = {
          enable = true;
          email = "hello@taxborn.com";
          baseUrl = "https://vw.mischief.town";
        };
        claude-code.enable = true;
        feh.enable = true;
        ghostty.enable = true;
        obs.enable = true;
        vlc.enable = true;
      };
    };
  };
}
