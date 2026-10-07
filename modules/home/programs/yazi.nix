{ lib, config, ... }:
let
  cfg = config.myHome.programs.yazi;
in
{
  options.myHome.programs.yazi.enable = lib.mkEnableOption "yazi file manager";

  config = lib.mkIf cfg.enable {
    programs.yazi = {
      enable = true;
      shellWrapperName = "y";
      enableFishIntegration = true;
      settings.manager.git_show = true;
    };

    programs.fish.interactiveShellInit = ''
      bind \co y
    '';
  };
}
