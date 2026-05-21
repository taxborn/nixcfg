{
  config,
  lib,
  pkgs,
  self,
  ...
}:
{
  options.myNixOS.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland wayland compositor";

    laptopMonitor = lib.mkOption {
      description = "Internal laptop monitor.";
      default = null;
      type = lib.types.nullOr lib.types.str;
    };

    monitors = lib.mkOption {
      description = "List of external monitors.";
      default = [ ];
      type = lib.types.listOf lib.types.str;
    };
  };

  config = lib.mkIf config.myNixOS.desktop.hyprland.enable {
    programs.hyprland = {
      enable = true;
      package = self.inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage =
        self.inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
    };

    xdg.portal = {
      enable = true;
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };

    security = {
      polkit.enable = true;
      pam.services.hyprlock = { };
    };

    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      nerd-fonts.jetbrains-mono
    ];

    services.dbus.enable = true;
  };
}
