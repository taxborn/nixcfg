{
  config,
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
    };

    home = {
      username = "taxborn";
      homeDirectory = "/home/taxborn";
      stateVersion = "25.11";
    };

    programs = {
      home-manager.enable = true;
      fish = {
        enable = true;
        interactiveShellInit = ''
          set fish_greeting # Disable greeting
        '';
      };
    };

    myHome.programs = {
      fzf.enable = true;
      git.enable = true;
      gpg.enable = true;
      neovim.enable = true;
      ripgrep.enable = true;
      tmux.enable = true;
      yazi.enable = true;
      yubikey.enable = true;
      zoxide.enable = true;
    };
  };
}
