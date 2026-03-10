{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.myHome.taxborn.programs.neovim.enable = lib.mkEnableOption "enable neovim";

  config = lib.mkIf config.myHome.taxborn.programs.neovim.enable {
    programs.fish.shellInit = lib.mkIf config.programs.fish.enable ''
      set -gx MANPAGER "nvim +Man!"
    '';

    programs.neovim = {
      enable = true;
      vimAlias = true;
      defaultEditor = true;

      # runtime deps: ripgrep/fd for telescope, gcc+make for telescope-fzf-native, git for lazy.nvim
      extraPackages = with pkgs; [
        ripgrep
        fd
        gcc
        gnumake
        unzip
        git
        tree-sitter
        lua-language-server
        stylua
      ];

      initLua = builtins.readFile ./init.lua;
    };
  };
}
