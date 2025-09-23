{
  pkgs,
  lib,
  config,
  ...
}:

with lib;
let
  cfg = config.features.desktop.etc;
in
{
  options.features.desktop.etc.enable = mkEnableOption "enable various desktop programs";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      discord
      obsidian
      spotify
    ];
  };
}
