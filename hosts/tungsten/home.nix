{
  self,
  lib,
  ...
}:
{
  home-manager.users.taxborn = {
    imports = [
      self.homeModules.profile-workstation
    ];

    config = {
      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        hl.on("hyprland.start", function()
            hl.exec_cmd("uwsm app -- swaybg -m fill -i ${../../assets/wallpapers/mountain.jpeg}")
        end)
      '';
    };
  };
}
