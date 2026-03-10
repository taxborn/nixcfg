{ lib, config, ... }:
{
  options.myHome.programs.yazi.enable = lib.mkEnableOption "yazi";

  config = lib.mkIf config.myHome.programs.yazi.enable {
    programs.yazi = {
      enable = true;
      enableFishIntegration = config.programs.fish.enable;
      shellWrapperName = "y";
    };
  };
}
