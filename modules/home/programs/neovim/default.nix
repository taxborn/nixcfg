{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myHome.programs.neovim;
in
{
  options.myHome.programs.neovim.enable = lib.mkEnableOption "neovim lua configuration";

  config = lib.mkIf cfg.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      withPython3 = false;
      withRuby = false;
      plugins = [ pkgs.vimPlugins.vim-tmux-navigator ];
      initLua = ''
        vim.g.tmux_navigator_no_mappings = 1
        require("config")
      '';
    };

    xdg.configFile."nvim/lua" = {
      source = ./lua;
      recursive = true;
    };
  };
}
