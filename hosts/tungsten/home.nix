{
  self,
  ...
}:
{
  home-manager.users.taxborn = {
    imports = [
      self.homeModules.profile-workstation
    ];

    config = {
      wayland.windowManager.hyprland.settings.env = [
        "GDK_SCALE,2"
        "XCURSOR_SIZE,48"
      ];
    };
  };
}
