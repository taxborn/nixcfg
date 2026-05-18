{
  config,
  lib,
  ...
}:
{
  options.myHome.services.mako.enable = lib.mkEnableOption "mako notification daemon";

  config = lib.mkIf config.myHome.services.mako.enable {
    services.mako.enable = true;
  };
}
