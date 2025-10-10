{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.features.development.rust;
in
{
  options.features.development.rust.enable = mkEnableOption "enable rust";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      rustc
      cargo
    ];
  };
}
