{ lib, config, pkgs, ... }:
let
in
{
  options.myHome.taxborn.programs.minecraft.enable = lib.mkEnableOption "minecraft";

  config = lib.mkIf config.myHome.taxborn.programs.minecraft.enable {
    home.packages = [ pkgs.prismlauncher ];
  };
}
