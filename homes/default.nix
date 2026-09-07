{ pkgs, self, ... }:
{
  imports = [
    self.homeModules.default
    self.homeModules.snippets
  ];

  config = {
    home = {
      username = "taxborn";
      homeDirectory = "/home/taxborn";
      stateVersion = "25.11";
      sessionPath = [ "$HOME/.local/bin" ];
      packages = with pkgs; [
        atproto-goat
        cargo
        gcc
        # The terminfo entry, not the terminal. This profile is the servers'
        # profile too, and ssh does not carry terminfo across, so without it a
        # ghostty window that lands on a server has an unknown $TERM.
        ghostty.terminfo
        gnumake
        jq
        just
        ncdu
        nodejs
        p7zip
        python3
        rustc
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

    myHome.programs = {
      fzf.enable = true;
      git.enable = true;
      gpg.enable = true;
      neovim.enable = true;
      ssh.enable = true;
      tmux.enable = true;
      yazi.enable = true;
    };

    # `autoEnable` themes every program the catppuccin module knows about,
    # which makes theming opt-out. A program that should keep its own colours
    # turns `catppuccin.<program>.enable` off rather than being added here.
    catppuccin = {
      accent = "mauve";
      autoEnable = true;
      cache.enable = true;
      enable = true;
      flavor = "mocha";
    };
  };
}
