{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.features.development.neovim;
in
{
  options.features.development.neovim.enable = mkEnableOption "enable neovim";

  config = mkIf cfg.enable {
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
  };
}
