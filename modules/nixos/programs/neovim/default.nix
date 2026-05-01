{
  config,
  lib,
  ...
}:
{
  options.myNixOS.programs.neovim.enable =
    lib.mkEnableOption "System-level neovim configuration. Meant to be used by root.";

  config = lib.mkIf config.myNixOS.programs.neovim.enable {
    programs.neovim = {
      enable = true;
      viAlias = true;
      vimAlias = true;
      defaultEditor = true;
    };
  };
}
