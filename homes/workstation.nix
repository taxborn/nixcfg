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
    dconf = {
      enable = true;
    };

    programs = {
      claude-code.enable = true;
      firefox = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
      };
      fish.shellAliases = {
        yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
        yk-resocket = "gpgconf --kill gpg-agent; systemctl --user restart gpg-agent.socket gpg-agent-ssh.socket";
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
      bitwarden-cli
      feh
      librepods
      nautilus
      opencode-desktop
      papers
      spotify
      vesktop
      vlc
    ];

    xdg.desktopEntries.lexidraw = {
      name = "Lexidraw";
      genericName = "Whiteboard";
      exec = "firefox --new-window https://lexidraw.app";
      icon = "applications-graphics";
      categories = [
        "Graphics"
        "Office"
      ];
      terminal = false;
    };

    services.gnome-keyring.enable = true;

    myHome = {
      desktop.niri.enable = true;
      programs = {
        ghostty.enable = true;
        gpg.agent.enable = true;
        nix-search.enable = true;
        yubikey.enable = true;
        zed.enable = true;
      };
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

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = "org.gnome.Papers.desktop";
        "inode/directory" = "org.gnome.Nautilus.desktop";
      };
    };

    # Preserve the file manager bookmarks independently of GTK theming.
    xdg.configFile."gtk-3.0/bookmarks".text = lib.concatMapStrings (dir: "file://${dir}\n") [
      config.xdg.userDirs.documents
      config.xdg.userDirs.download
      config.xdg.userDirs.music
      config.xdg.userDirs.videos
      config.xdg.userDirs.pictures
    ];

    # Keep application themes, but let the new shell own desktop appearance.
    catppuccin = {
      gtk.icon.enable = false;
      cursors.enable = false;
    };
  };
}
