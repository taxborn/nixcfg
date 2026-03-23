{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.myHome.programs.minecraft.enable = lib.mkEnableOption "minecraft";

  config = lib.mkIf config.myHome.programs.minecraft.enable {
    home.packages = [ pkgs.prismlauncher ];
  };
}
