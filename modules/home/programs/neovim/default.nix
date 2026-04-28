{
  lib,
  config,
  ...
}:
{
  options.myHome.programs.neovim.enable = lib.mkEnableOption "User-level neovim configuration.";

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
    };
  };
}
