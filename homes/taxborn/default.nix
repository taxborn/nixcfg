{
  config,
  pkgs,
  self,
  ...
}:
{
  imports = [
    self.homeModules.default
  ];

  config = {
    nix = {
      inherit (config.mySnippets.nix) settings;

      gc = {
        automatic = true;
        options = "--delete-older-than 3d";
        persistent = true;
        randomizedDelaySec = "60min";
      };
    };

    xdg.enable = true;

    home = {
      username = "taxborn";
      homeDirectory = "/home/taxborn";
      stateVersion = "25.11";

      packages = with pkgs; [
        discord
        obsidian
        spotify
      ];
    };

    programs = {
      home-manager.enable = true;
      zen-browser = {
        enable = true;
        nativeMessagingHosts = [ pkgs.bitwarden-desktop ];
      };

      fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting # Disable greeting

          set -gx GPG_TTY (tty)
          set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
          gpgconf --launch gpg-agent
          gpg-connect-agent updatestartuptty /bye > /dev/null
        '';
        shellAliases = {
          nix-rb = "sudo nixos-rebuild switch --flake .";
          yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
        };
      };
    };

    # TODO: Most of these should probably move to the per-host home config.
    myHome = {
      taxborn.programs = {
        git.enable = true;
        gpg.enable = true;
        minecraft.enable = true;
        tmux.enable = true;
        yubikey.enable = true;
        zed-editor.enable = true;
      };
      profiles.defaultApps.enable = true;
      desktop.hyprland.enable = true;
      programs = {
        ghostty.enable = true;
        obs.enable = true;
      };
    };
  };
}
