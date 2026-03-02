{ lib, config, ... }:
{
  options.myHome.programs.feh.enable = lib.mkEnableOption "feh";

  config = lib.mkIf config.myHome.programs.feh.enable {
    programs.feh.enable = true;
  };
}
