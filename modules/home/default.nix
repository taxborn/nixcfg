{ osConfig, pkgs, ... }:
{
  imports = [
    ./programs/fzf.nix
    ./programs/git.nix
    ./programs/gpg.nix
    ./programs/neovim
    ./programs/ssh.nix
    ./programs/tmux.nix
    ./programs/yazi.nix
  ];

  config = {
    home = {
      username = osConfig.homelab.owner.username;
      homeDirectory = "/home/${osConfig.homelab.owner.username}";
      stateVersion = "25.11";
      sessionPath = [ "$HOME/.local/bin" ];
      # Servers get this profile too, so no toolchains here.
      packages = with pkgs; [
        atproto-goat
        ghostty.terminfo
        jq
        just
        ncdu
        p7zip
        unzip
        xh
      ];
    };

    programs = {
      bat.enable = true;
      direnv = {
        enable = true;
        nix-direnv.enable = true;
      };
      eza = {
        enable = true;
        enableFishIntegration = true;
        git = true;
        icons = "auto";
        extraOptions = [ "--group-directories-first" ];
      };
      fd.enable = true;
      fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting # emptying it is what silences the greeting
        '';
      };
      home-manager.enable = true;
      ripgrep.enable = true;
      zoxide = {
        enable = true;
        enableFishIntegration = true;
      };
    };

    catppuccin = {
      accent = "mauve";
      autoEnable = true;
      cache.enable = true;
      enable = true;
      flavor = "mocha";
    };
  };
}
