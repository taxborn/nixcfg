{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.neovim.enable = lib.mkEnableOption "neovim lua configuration";

  config = lib.mkIf config.myHome.programs.neovim.enable {
    programs.neovim = {
      enable = true;
      defaultEditor = true;
      vimAlias = true;
      withPython3 = false;
      withRuby = false;
      initLua = ''
        require("config")
      '';
    };

    xdg.configFile."nvim/lua" = {
      source = ./lua;
      recursive = true;
    };
  };
}
