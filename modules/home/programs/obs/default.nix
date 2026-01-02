{ lib, config, ... }:
let
in
{
  options.myHome.programs.obs.enable = lib.mkEnableOption "rofi application launcher";

  config = lib.mkIf config.myHome.programs.obs.enable {
    programs.obs-studio.enable = true;
  };
}
