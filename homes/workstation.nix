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
      nautilus
      papers
      spotify
      vesktop
      vlc
      feh
    ];

    # Excalidraw has no Linux desktop build in nixpkgs -- only the export CLI
    # and the font. The hosted app registers a service worker on first load and
    # keeps drawings in local storage, so it works offline after that; this is
    # the real thing rather than a substitute like drawio.
    xdg.desktopEntries.excalidraw = {
      name = "Excalidraw";
      genericName = "Whiteboard";
      exec = "firefox --new-window https://excalidraw.com";
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
        # Workstation-only: the prebuilt nix-index database is ~100 MiB, and the
        # machines that get edited are the ones this repo is edited from.
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

    # Without these, xdg-open has no handler for either type: nothing claimed
    # application/pdf at all, and inode/directory only ever resolved to
    # whatever GTK guessed, since yazi ships no desktop entry.
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        "application/pdf" = "org.gnome.Papers.desktop";
        "inode/directory" = "org.gnome.Nautilus.desktop";
      };
    };

    gtk = {
      # catppuccin.gtk.icon only *names* the icon theme (Papirus-Dark); it is
      # home-manager's gtk module that installs the package and writes
      # gtk-icon-theme-name. Without this the session has no icon theme at all
      # and GTK falls back to a near-empty hicolor, so Waybar's tray cannot
      # resolve the icon names nm-applet publishes over StatusNotifierItem and
      # logs "Could not find an icon named 'nm-...'" for every animation frame.
      enable = true;

      gtk3.bookmarks = [
        "file://${config.xdg.userDirs.documents}"
        "file://${config.xdg.userDirs.download}"
        "file://${config.xdg.userDirs.music}"
        "file://${config.xdg.userDirs.videos}"
        "file://${config.xdg.userDirs.pictures}"
      ];
    };

    catppuccin = {
      gtk.icon.enable = true;
      cursors.enable = true;
    };
  };
}
