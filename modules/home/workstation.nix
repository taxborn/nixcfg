{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  imports = [
    ./niri
    ./programs/ghostty.nix
    ./programs/nix-search.nix
    ./programs/yubikey.nix
    ./programs/zed.nix
  ];

  config = {
    dconf = {
      enable = true;
    };

    programs = {
      atuin = {
        enable = true;
        enableFishIntegration = true;
        settings = {
          sync_address = "https://${osConfig.homelab.services.atuin.domain}";
          auto_sync = true;
          sync_frequency = "5m";
        };
      };
      fzf.historyWidget.command = "";
      firefox = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
      };
      nix-your-shell = {
        enable = true;
        enableFishIntegration = true;
      };
      fish.shellAliases = {
        yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
        yk-resocket = "gpgconf --kill gpg-agent; systemctl --user restart gpg-agent.socket gpg-agent-ssh.socket";
      };
      obsidian = {
        enable = true;
        cli.enable = true;
        package = pkgs.obsidian.override { electron = pkgs.electron_44; };
      };
      obs-studio.enable = true;
    };

    home.packages = with pkgs; [
      bitwarden-desktop
      bitwarden-cli
      feh
      dix
      librepods
      nautilus
      nix-output-monitor
      papers
      pwvucontrol
      spotify
      vesktop
      vlc

      cargo
      gcc
      gnumake
      nodejs
      python3
      rustc
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

    services.gpg-agent = {
      enable = true;
      enableSshSupport = true;

      extraConfig = ''
        ttyname $GPG_TTY
      '';
      defaultCacheTtl = 60;
      maxCacheTtl = 120;

      pinentry.package = pkgs.pinentry-gnome3;
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

    xdg.configFile."gtk-3.0/bookmarks".text = lib.concatMapStrings (dir: "file://${dir}\n") [
      config.xdg.userDirs.documents
      config.xdg.userDirs.download
      config.xdg.userDirs.music
      config.xdg.userDirs.videos
      config.xdg.userDirs.pictures
    ];

    catppuccin = {
      gtk.icon.enable = false;
      cursors.enable = false;
    };
  };
}
