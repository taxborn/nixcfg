{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.features.development.python;
in
{
  options.features.development.python.enable = mkEnableOption "enable python";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      uv
    ];
  };
}
