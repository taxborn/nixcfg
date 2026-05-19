{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.ghostty.enable = lib.mkEnableOption "Ghostty terminal";

  config = lib.mkIf config.myHome.programs.ghostty.enable {
    programs.ghostty = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        font-family = "JetBrainsMono NFM";
        font-size = 12;
        shell-integration = "fish";
        confirm-close-surface = false;
        theme = "catppuccin-mocha.conf";
      };
    };

    home.file.".config/ghostty/themes/catppuccin-mocha.conf".source = ./catppuccin-mocha.conf;
  };
}
