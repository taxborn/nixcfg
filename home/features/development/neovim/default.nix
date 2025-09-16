{ pkgs, ... }:

{
  xdg.configFile."nvim" = {
    source = ./config;
    recursive = true;
  };

  home.packages = with pkgs; [
    nodejs_24
    gcc
    fd
  ];

  programs.neovim = {
    enable = true;
    withNodeJs = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;
  };
}
