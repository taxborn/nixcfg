{
  config,
  lib,
  ...
}:
let
  cfg = config.myHome.programs.zed;
in
{
  options.myHome.programs.zed.enable = lib.mkEnableOption "Zed editor";

  config = lib.mkIf cfg.enable {
    programs.zed-editor = {
      enable = true;
      installRemoteServer = true;
    };
  };
}
