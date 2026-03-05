{ lib, config, ... }:
{
  options.myHome.programs.bat.enable = lib.mkEnableOption "bat";

  config = lib.mkIf config.myHome.programs.bat.enable {
    programs.bat.enable = true;
  };
}
