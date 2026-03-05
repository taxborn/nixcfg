{
  config,
  lib,
  ...
}:
{
  options.myNixOS.programs.neovim.enable = lib.mkEnableOption "neovim";

  config = lib.mkIf config.myNixOS.programs.neovim.enable {
    programs.neovim = {
      enable = true;
      vimAlias = true;
      defaultEditor = true;
    };
  };
}
