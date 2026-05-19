{ config, pkgs, ... }:
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
      claude-code.enable = true;
      firefox = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
      };
      obsidian = {
        enable = true;
        cli.enable = true;
      };
      feh.enable = true;
    };

    home.packages = with pkgs; [
      swaybg
      spotify
      bitwarden-desktop
      vlc
    ];

    myHome = {
      desktop.hyprland.enable = true;
      programs = {
        direnv.enable = true;
        ghostty.enable = true;
        waybar.enable = true;
        wofi.enable = true;
        yubikey.enable = true;
        zed.enable = true;
      };
      services.mako.enable = true;
    };

    catppuccin = {
      enable = true;
      flavor = "mocha";
      accent = "mauve";
      gtk.icon.enable = true;
      cursors.enable = true;
    };
  };
}
