{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.taxborn.desktop.hyprland.enable = lib.mkOption {
    type = lib.types.bool;
    default = config.myHome.desktop.hyprland.enable && config.home.username == "taxborn";
    description = "Enable taxborn's Hyprland environment.";
  };

  config = lib.mkIf config.myHome.taxborn.desktop.hyprland.enable {
    wayland.windowManager.hyprland.settings = {
      bind = [
        "$mod SHIFT,D,movetoworkspace,special:discord"
        "$mod,D,togglespecialworkspace,discord"
        "$mod,N,exec,${lib.getExe' pkgs.obsidian "obsidian"}"
      ];
    };

    myHome.services.swaybg.enable = true;
  };
}
