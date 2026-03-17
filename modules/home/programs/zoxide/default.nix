{ lib, config, ... }:
{
  options.myHome.programs.zoxide.enable = lib.mkEnableOption "zoxide";

  config = lib.mkIf config.myHome.programs.zoxide.enable {
    programs.zoxide = {
      enable = true;
      enableFishIntegration = true;
    };
  };
}
