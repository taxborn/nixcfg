{
  config,
  lib,
  osConfig,
  pkgs,
  self,
  ...
}:
let
  hyprNixOS = osConfig.myNixOS.desktop.hyprland or { };
  laptopMonitor = hyprNixOS.laptopMonitor or null;
  externalMonitors = hyprNixOS.monitors or [ ];
  configuredMonitors = lib.optional (laptopMonitor != null) laptopMonitor ++ externalMonitors;
  monitors = if configuredMonitors == [ ] then [ ",preferred,auto,1" ] else configuredMonitors;
in
{
  imports = [
    self.inputs.hyprland.homeManagerModules.default
  ];

  options.myHome.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland home-manager configuration";
  };

  config = lib.mkIf config.myHome.desktop.hyprland.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      xwayland.enable = true;
      package = self.inputs.hyprland.packages.${pkgs.system}.hyprland;
      portalPackage = self.inputs.hyprland.packages.${pkgs.system}.xdg-desktop-portal-hyprland;
      systemd.enable = false; # UWSM manages the session
      configType = "lua";
      settings.monitor = monitors;
      extraConfig = ''
        ${builtins.readFile ./config.lua}
      '';
    };
  };
}
