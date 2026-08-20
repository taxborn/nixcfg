{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./default.nix
  ];

  config = {
    dconf.enable = true;
    programs = {
      claude-code.enable = true;
      firefox = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
      };
      fish.shellAliases = {
        yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
        yk-resocket = "gpgconf --kill gpg-agent; systemctl --user restart gpg-agent.socket gpg-agent-ssh.socket gpg-agent-extra.socket";
      };
      obsidian = {
        enable = true;
        cli.enable = true;
      };
      obs-studio.enable = true;
      t3code.enable = true;
    };

    home.packages = with pkgs; [
      bitwarden-desktop
      spotify
      vesktop
      vlc
      feh
    ];

    services.gnome-keyring.enable = true;

    myHome = {
      desktop.hyprland.enable = true;
      programs = {
        ghostty.enable = true;
        gpg.agent.enable = true;
        hyprland.enable = true;
        # Workstation-only: the prebuilt nix-index database is ~100 MiB, and the
        # machines that get edited are the ones this repo is edited from.
        nix-search.enable = true;
        yubikey.enable = true;
        zed.enable = true;
      };
      services.hypridle.enable = true;
    };

    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = false;
      desktop = lib.mkDefault "${config.home.homeDirectory}/desktop";
      documents = lib.mkDefault "${config.home.homeDirectory}/documents";
      download = lib.mkDefault "${config.home.homeDirectory}/downloads";
      music = lib.mkDefault "${config.home.homeDirectory}/media/music";
      pictures = lib.mkDefault "${config.home.homeDirectory}/media/photos";
      videos = lib.mkDefault "${config.home.homeDirectory}/media/video";
      templates = lib.mkDefault "${config.home.homeDirectory}/templates";
      publicShare = lib.mkDefault "${config.home.homeDirectory}/public";
      projects = null;
    };

    gtk.gtk3.bookmarks = [
      "file://${config.xdg.userDirs.documents}"
      "file://${config.xdg.userDirs.download}"
      "file://${config.xdg.userDirs.music}"
      "file://${config.xdg.userDirs.videos}"
      "file://${config.xdg.userDirs.pictures}"
    ];

    catppuccin = {
      gtk.icon.enable = true;
      cursors.enable = true;
    };
  };
}
