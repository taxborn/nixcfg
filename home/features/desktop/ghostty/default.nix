{
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.features.desktop.ghostty;
in
{
  options.features.desktop.ghostty.enable = mkEnableOption "enable ghostty terminal";

  config = mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      settings = {
        font-family = "Atkinson Hyperlegible Mono";
        window-padding-x = 4;
        window-padding-y = 4;
        theme = "catppuccin-mocha.conf";
      };
    };

    home.file.".config/ghostty/themes/catppuccin-mocha.conf".source = ./catppuccin-mocha.conf;
  };
}
