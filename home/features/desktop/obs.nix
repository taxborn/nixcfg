{ lib, config, ... }:
with lib;
let
  cfg = config.features.desktop.obs;
in
{
  options.features.desktop.obs.enable = mkEnableOption "enable obs studio";

  config = mkIf cfg.enable {
    programs.obs-studio.enable = true;
  };
}
