{
  config,
  lib,
  ...
}:
{
  options.myHome.services.mako.enable = lib.mkEnableOption "mako notification daemon";

  config = lib.mkIf config.myHome.services.mako.enable {
    services.mako = {
      enable = true;
      settings = {
        anchor = "top-right";
        background-color = "#1e1e2e";
        text-color = "#cdd6f4";
        border-color = "#89b4fa";
        border-size = 2;
        border-radius = 6;
        default-timeout = 5000;
        font = "JetBrainsMono Nerd Font 11";
        margin = 12;
        padding = 12;
        width = 360;
        height = 120;
      };
    };
  };
}
