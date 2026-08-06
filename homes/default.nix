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
      packages = with pkgs; [ just ghostty.terminfo ];
    };

    programs = {
      fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting # Disable greeting
        '';
      };
      home-manager.enable = true;
      ripgrep.enable = true;
      fd.enable = true;
      neovim = {
        enable = true;
        defaultEditor = true;
        vimAlias = true;
        withPython3 = false;
        withRuby = false;
      };
    };

    myHome.programs = {
      fzf.enable = true;
      git.enable = true;
      gpg.enable = true;
      ssh.enable = true;
      tmux.enable = true;
      yazi.enable = true;
    };
  };
}
