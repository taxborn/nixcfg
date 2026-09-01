{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.catppuccin) accent flavor;

  gtkTheme = {
    name = "catppuccin-${flavor}-${accent}-standard";
    package = pkgs.catppuccin-gtk.override {
      variant = flavor;
      accents = [ accent ];
    };
  };
in
{
  imports = [
    ./default.nix
  ];

  config = {
    dconf = {
      enable = true;
      settings."org/gnome/desktop/interface".color-scheme = "prefer-dark";
    };
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
      nautilus
      papers
      spotify
      vesktop
      vlc
      feh
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
      desktop.hyprland.enable = true;
      programs = {
        cliphist.enable = true;
        ghostty.enable = true;
        gpg.agent.enable = true;
        hyprland.enable = true;
        nix-search.enable = true;
        screenshot.enable = true;
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

    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = "org.gnome.Papers.desktop";
        "inode/directory" = "org.gnome.Nautilus.desktop";
      };
    };

    gtk = {
      enable = true;
      theme = gtkTheme;
      gtk4.theme = gtkTheme;
      colorScheme = "dark";
      gtk3.bookmarks = [
        "file://${config.xdg.userDirs.documents}"
        "file://${config.xdg.userDirs.download}"
        "file://${config.xdg.userDirs.music}"
        "file://${config.xdg.userDirs.videos}"
        "file://${config.xdg.userDirs.pictures}"
      ];
    };

    qt = {
      enable = true;
      platformTheme.name = "qtct";
      style.name = "kvantum";
      qt5ctSettings.Appearance.icon_theme = config.gtk.iconTheme.name;
      qt6ctSettings.Appearance.icon_theme = config.gtk.iconTheme.name;
    };

    catppuccin = {
      gtk.icon.enable = true;
      cursors.enable = true;
    };
  };
}
