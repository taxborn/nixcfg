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
        cargo
        ghostty.terminfo
        jq
        just
        ncdu
        nodejs
        p7zip
        rustc
        unzip
      ];
    };

    programs = {
      bat.enable = true;
      # nix-direnv swaps the stock `use nix` for a version that pins the
      # devShell as a GC root and caches its environment, so entering a
      # directory is a file read rather than a nix evaluation -- and the shell
      # survives the `--delete-older-than 3d` collection in programs/nix.nix.
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
          set fish_greeting # Disable greeting
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

    catppuccin = {
      accent = "mauve";
      autoEnable = true;
      cache.enable = true;
      enable = true;
      flavor = "mocha";
    };
  };
}
