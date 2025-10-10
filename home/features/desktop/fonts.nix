{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.features.desktop.fonts;
in
{
  options.features.desktop.fonts.enable = mkEnableOption "enable my fonts";

  config = mkIf cfg.enable {
    fonts.fontconfig.enable = true;

    home.packages = with pkgs; [
      # Nerd fonts
      nerd-fonts.jetbrains-mono

      # noto
      noto-fonts
      noto-fonts-color-emoji

      # Accessible fonts
      atkinson-hyperlegible-next
      atkinson-hyperlegible-mono
    ];
  };
}
