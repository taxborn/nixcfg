{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.features.desktop.minecraft;
in
{
  options.features.desktop.minecraft.enable = mkEnableOption "enable minecraft";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      prismlauncher
    ];
  };
}
