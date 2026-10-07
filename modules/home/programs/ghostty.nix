{
  config,
  lib,
  ...
}:
let
  cfg = config.myHome.programs.ghostty;
in
{
  options.myHome.programs.ghostty.enable = lib.mkEnableOption "Ghostty terminal";

  config = lib.mkIf cfg.enable {
    programs.ghostty = {
      enable = true;
      enableFishIntegration = true;
      settings = {
        font-family = "JetBrainsMono NFM";
        font-size = 12;
        shell-integration = "fish";
        confirm-close-surface = false;
        window-padding-x = 8;
        window-padding-y = 8;
      };
    };
  };
}
