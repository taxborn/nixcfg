{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (config.catppuccin) accent flavor;

  # catppuccin/nix dropped its GTK port when catppuccin/gtk was archived; only
  # the Papirus icon override survives there, so the widget theme comes from
  # nixpkgs directly.
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

      # libadwaita apps (Nautilus, Papers) ignore gtk-theme-name entirely and
      # ask xdg-desktop-portal for `org.freedesktop.appearance` color-scheme.
      # xdg-desktop-portal-gtk answers that from this GSetting, so without it
      # they render light no matter what the GTK theme says.
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

      # GTK2/3 read gtk-theme-name from settings.ini. GTK4 writes that key too
      # but ignores it, so home-manager @imports the theme's stylesheet into
      # ~/.config/gtk-4.0/gtk.css -- the one hook libadwaita still honours --
      # which is why gtk4 has to name the theme rather than inherit it.
      theme = gtkTheme;
      gtk4.theme = gtkTheme;

      # Emits gtk-application-prefer-dark-theme for the GTK3 apps that predate
      # the portal; the dconf key above is what everything else reads.
      colorScheme = "dark";

      gtk3.bookmarks = [
        "file://${config.xdg.userDirs.documents}"
        "file://${config.xdg.userDirs.download}"
        "file://${config.xdg.userDirs.music}"
        "file://${config.xdg.userDirs.videos}"
        "file://${config.xdg.userDirs.pictures}"
      ];
    };

    # Qt has no portal equivalent: apps read QT_QPA_PLATFORMTHEME and
    # QT_STYLE_OVERRIDE instead. catppuccin.kvantum auto-enables off
    # `qt.enable` and asserts the style below.
    qt = {
      enable = true;
      platformTheme.name = "qtct";
      style.name = "kvantum";

      # Kvantum only paints widgets. Icons come from the platform theme, which
      # has no GTK settings.ini to fall back on, so name the same theme twice.
      qt5ctSettings.Appearance.icon_theme = config.gtk.iconTheme.name;
      qt6ctSettings.Appearance.icon_theme = config.gtk.iconTheme.name;
    };

    catppuccin = {
      gtk.icon.enable = true;
      cursors.enable = true;
    };
  };
}
