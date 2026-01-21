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

      workspace = [
        "1,defaultName:web,on-created-empty:${config.myHome.profiles.defaultApps.webBrowser.exec}"
        "2,defaultName:note,on-created-empty:${lib.getExe' pkgs.obsidian "obsidian"}"
        "3,defaultName:code,on-created-empty:${config.myHome.profiles.defaultApps.editor.exec}"
        "4,defaultName:mail,on-created-empty:${lib.getExe config.programs.thunderbird.package}"
      ];
    };

    myHome.services.swaybg.enable = true;
  };
}
