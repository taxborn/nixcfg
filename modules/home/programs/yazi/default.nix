{ lib, config, ... }:
{
  options.myHome.programs.yazi.enable = lib.mkEnableOption "yazi file manager";

  config = lib.mkIf config.myHome.programs.yazi.enable {
    programs.yazi = {
      enable = true;
      shellWrapperName = "y";
      enableFishIntegration = true;
      settings = {
        manager.show_hidden = false;
        manager.git_show = true;
      };
    };

    programs.fish.interactiveShellInit = ''
      bind \co y
    '';
  };
}
