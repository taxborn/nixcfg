{
  self,
  lib,
  pkgs,
  ...
}:
{
  home-manager.users.taxborn = {
    imports = [
      self.homeModules.profile-workstation
    ];

    config = {
      home.packages = with pkgs; [
        via
        prismlauncher
      ];

      wayland.windowManager.hyprland.extraConfig = lib.mkAfter ''
        hl.on("hyprland.start", function()
            hl.exec_cmd("swaybg -m fill -i ${../../assets/wallpapers/island.jpeg}")
        end)
      '';
    };
  };
}
