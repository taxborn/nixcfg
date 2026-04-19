{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.myHome.programs.neovim.enable = lib.mkEnableOption "enable neovim";

  config = lib.mkIf config.myHome.programs.neovim.enable {
    programs.fish.shellInit = lib.mkIf config.programs.fish.enable ''
      set -gx MANPAGER "nvim +Man!"
    '';

    programs.neovim = {
      enable = true;
      vimAlias = true;
      defaultEditor = true;
      withRuby = false;
      withPython3 = false;

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
        astro-language-server
        typescript
      ];

    };

    xdg.configFile = {
      "nvim/init.lua" = lib.mkForce {
        source = config.lib.file.mkOutOfStoreSymlink "/home/taxborn/dev/nix-infra/nixcfg/modules/home/programs/neovim/config/init.lua";
      };
      "nvim/lua".source =
        config.lib.file.mkOutOfStoreSymlink "/home/taxborn/dev/nix-infra/nixcfg/modules/home/programs/neovim/config/lua";
      "nvim/plugin".source =
        config.lib.file.mkOutOfStoreSymlink "/home/taxborn/dev/nix-infra/nixcfg/modules/home/programs/neovim/config/plugin";
      "nvim/nvim-pack-lock.json".source =
        config.lib.file.mkOutOfStoreSymlink "/home/taxborn/dev/nix-infra/nixcfg/modules/home/programs/neovim/config/nvim-pack-lock.json";
    };
  };
}
