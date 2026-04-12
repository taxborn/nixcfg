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

    home = {
      username = "taxborn";
      homeDirectory = "/home/taxborn";
      stateVersion = "25.11";

      sessionPath = [
        "$HOME/.zvm/bin"
        "$HOME/.local/bin"
        "$HOME/go/bin"
      ];

      packages = with pkgs; [
        clang
        go
        rustc
        cargo
        jdk
        uv
        fnm
        zvm
      ];
    };

    programs = {
      home-manager.enable = true;
      fish = {
        enable = true;
        interactiveShellInit = ''
          fnm env --use-on-cd --shell fish | source
        '';
      };
    };

    myHome.programs = {
      bat.enable = true;
      eza.enable = true;
      fd.enable = true;
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
