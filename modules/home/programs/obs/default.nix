{ lib, config, ... }:
{
  options.myHome.programs.obs.enable = lib.mkEnableOption "obs studio";

  config = lib.mkIf config.myHome.programs.obs.enable {
    programs.obs-studio.enable = true;
  };
}
