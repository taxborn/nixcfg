{
  pkgs,
  lib,
  config,
  ...
}:
with lib;
let
  cfg = config.features.development.zig;
in
{
  options.features.development.zig.enable = mkEnableOption "enable zig";

  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      # zig
      # zls
      zvm
    ];
  };
}
