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
  configuredMonitors =
    lib.optional (laptopMonitor != null) laptopMonitor ++ externalMonitors;
  monitors =
    if configuredMonitors == [ ] then [ ",preferred,auto,1" ] else configuredMonitors;
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

      settings = {
        "$mod" = "SUPER";
        "$terminal" = "ghostty";
        "$menu" = "wofi --show drun";

        monitor = monitors;

        exec-once = [
          "uwsm app -- waybar"
          "uwsm app -- mako"
        ];

        general = {
          gaps_in = 4;
          gaps_out = 8;
          border_size = 2;
          layout = "dwindle";
        };

        decoration = {
          rounding = 6;
        };

        input = {
          kb_layout = "us";
          follow_mouse = 1;
          touchpad.natural_scroll = true;
        };

        bind = [
          "$mod, Return, exec, uwsm app -- $terminal"
          "$mod, D, exec, uwsm app -- $menu"
          "$mod, Q, killactive"
          "$mod SHIFT, E, exec, uwsm stop"
          "$mod, F, fullscreen"
          "$mod, Space, togglefloating"

          "$mod, H, movefocus, l"
          "$mod, L, movefocus, r"
          "$mod, K, movefocus, u"
          "$mod, J, movefocus, d"

          "$mod, 1, workspace, 1"
          "$mod, 2, workspace, 2"
          "$mod, 3, workspace, 3"
          "$mod, 4, workspace, 4"
          "$mod, 5, workspace, 5"

          "$mod SHIFT, 1, movetoworkspace, 1"
          "$mod SHIFT, 2, movetoworkspace, 2"
          "$mod SHIFT, 3, movetoworkspace, 3"
          "$mod SHIFT, 4, movetoworkspace, 4"
          "$mod SHIFT, 5, movetoworkspace, 5"
        ];

        bindm = [
          "$mod, mouse:272, movewindow"
          "$mod, mouse:273, resizewindow"
        ];
      };
    };
  };
}
