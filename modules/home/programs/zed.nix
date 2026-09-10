{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.zed.enable = lib.mkEnableOption "Zed editor";

  config = lib.mkIf config.myHome.programs.zed.enable {
    programs.zed-editor = {
      enable = true;
      installRemoteServer = true;
    };
  };
}
