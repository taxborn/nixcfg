{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.wofi.enable = lib.mkEnableOption "wofi application launcher";

  config = lib.mkIf config.myHome.programs.wofi.enable {
    programs.wofi = {
      enable = true;
      settings = {
        show = "drun";
        prompt = "Run";
        insensitive = true;
      };
    };
  };
}
