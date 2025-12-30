{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  imports = [
    self.homeModules.default
  ];

  config = {
      nix = {
        # inherit (config.mySnippets.nix) settings;
        gc = {
          automatic = true;
          options = "--delete-older-than 3d";
          persistent = true;
          randomizedDelaySec = "60min";
        };

        settings = {
          experimental-features = [
            "fetch-closure"
            "flakes"
            "nix-command"
          ];

          trusted-users = [ "taxborn" "@admin" "@wheel" ];
        };
      };

    xdg.enable = true;

    home = {
      username = "taxborn";
      homeDirectory = lib.mkForce "/home/taxborn"; # TODO: i dont wanna force this
      stateVersion = "25.11";

      packages = with pkgs; [
        obsidian
        yubikey-manager
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
          # set -gx PATH $PATH $HOME/bin $HOME/.local/bin $HOME/.zvm/bin

          set -gx GPG_TTY (tty)
          set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
          gpgconf --launch gpg-agent
          gpg-connect-agent updatestartuptty /bye > /dev/null
        '';
        shellAliases = {
          nix-rb = "sudo nixos-rebuild switch --flake /home/taxborn/nixcfg"; # TODO: I think there is an env variable to set the dir
          yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
        };
      };
    };

    myHome = {
      taxborn.programs = {
        zed-editor.enable = true;
        git.enable = true;
        gpg.enable = true;
      };
      programs.ghostty.enable = true;
    };
  };
}
