{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.ghostty.enable = lib.mkEnableOption "ghostty terminal emulator";

  config = lib.mkIf config.myHome.programs.ghostty.enable {
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
