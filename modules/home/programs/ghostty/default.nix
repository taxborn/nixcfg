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
        theme = "catppuccin-mocha";
        font-family = "JetBrainsMono Nerd Font";
        font-size = 12;
        window-padding-x = 8;
        window-padding-y = 8;
        cursor-style = "bar";
        shell-integration = "fish";
        confirm-close-surface = false;
      };
    };
  };
}
