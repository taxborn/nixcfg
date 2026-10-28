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
      # Syncs to the self-hosted server on Argon. History is encrypted on this
      # machine with a key that never leaves it, so the server stores
      # ciphertext. `atuin register` once, then `atuin key` to carry the key to
      # another machine. Until an account exists, `auto_sync` fails quietly
      # and history stays local.
      atuin = {
        enable = true;
        enableFishIntegration = true;
        settings = {
          sync_address = "https://${config.mySnippets.biscuits-at.networkMap.atuin.domain}";
          auto_sync = true;
          sync_frequency = "5m";
        };
      };
      # Atuin owns Ctrl-R. fzf keeps Ctrl-T for files and Alt-C for directories.
      fzf.historyWidget.command = "";
      claude-code.enable = true;
      codex.enable = true;
      firefox = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox";
      };
      lazygit.enable = true;
      # Keeps fish as the shell inside `nix develop` and `nix shell`, which
      # otherwise drop into bash.
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
        # electron 43.8.3 breaks the renderer preload (webFrame, "reading
        # 'defineProperty'") and the window never opens. 43.7.11 and 44 are fine.
        package = pkgs.obsidian.override { electron = pkgs.electron_44; };
      };
      obs-studio.enable = true;
    };

    home.packages = with pkgs; [
      bitwarden-desktop
      bitwarden-cli
      feh
      dix # closure diff, run after a rebuild to see what changed
      librepods
      nautilus
      nix-output-monitor
      papers
      pwvucontrol
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
