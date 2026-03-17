{ lib, config, ... }:
{
  options.myHome.programs.ripgrep.enable = lib.mkEnableOption "ripgrep";

  config = lib.mkIf config.myHome.programs.ripgrep.enable {
    programs.ripgrep = {
      enable = true;
    };
  };
}
