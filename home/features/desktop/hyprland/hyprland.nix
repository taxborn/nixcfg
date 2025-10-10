{
  pkgs,
  osConfig,
  ...
}:
let
  hostname = osConfig.networking.hostName;
  uraniumMonitorConfig = ''
    monitor = DP-5,2560x1440@165,0x0,1
    monitor = HDMI-A-5,1920x1080@60,2560x320,1
  '';
  tungstenMonitorConfig = ''
    monitor = eDP-1,3456x2160@60,0x0,2
  '';
  defaultMonitorConfig = ''
    monitor=,preferred,auto,auto
  '';
in
{
  home.packages = with pkgs; [
    hyprpolkitagent
    wofi
    playerctl
  ];

  programs.hyprlock.enable = true;

  wayland.windowManager.hyprland.extraConfig =
    if hostname == "uranium" then
      uraniumMonitorConfig
    else if hostname == "tungsten" then
      tungstenMonitorConfig
    else
      defaultMonitorConfig;

  wayland.windowManager.hyprland = {
    enable = true;
    package = pkgs.hyprland;
    systemd = {
      enable = true;
      enableXdgAutostart = true;
      variables = [ "--all" ];
    };

    xwayland.enable = true;

    settings = {
      # Program variables
      "$terminal" = "ghostty";
      "$menu" = "wofi --show drun";
      "$mainMod" = "SUPER";

      # Autostart
      exec-once = [
        "$terminal"
        "zen-beta"
      ];

      # Environment variables
      env = [
        "XCURSOR_SIZE,24"
        "HYPRCURSOR_SIZE,24"
      ];

      # General settings
      general = {
        gaps_in = 4;
        gaps_out = 4;
        border_size = 0;
        "col.active_border" = "rgba(00000000)";
        "col.inactive_border" = "rgba(00000000)";
        resize_on_border = false;
        allow_tearing = false;
        layout = "dwindle";
      };

      # Decoration
      decoration = {
        rounding = 6;
        rounding_power = 2;
        active_opacity = 0.97;
        inactive_opacity = 0.9;

        shadow.enabled = false;
        blur.enabled = false;
      };

      # Animations
      animations = {
        enabled = true;

        bezier = [
          "easeOutQuint,0.23,1,0.32,1"
          "easeInOutCubic,0.65,0.05,0.36,1"
          "linear,0,0,1,1"
          "almostLinear,0.5,0.5,0.75,1.0"
          "quick,0.15,0,0.1,1"
        ];

        animation = [
          "global, 1, 2, default"
          "border, 1, 2, easeOutQuint"
          "windows, 1, 2, easeOutQuint"
          "windowsIn, 1, 2, easeOutQuint, popin 87%"
          "windowsOut, 1, 2, linear, popin 87%"
          "fadeIn, 1, 2, almostLinear"
          "fadeOut, 1, 2, almostLinear"
          "fade, 1, 2, quick"
          "layers, 1, 2, easeOutQuint"
          "layersIn, 1, 2, easeOutQuint, fade"
          "layersOut, 1, 2, linear, fade"
          "fadeLayersIn, 1, 2, almostLinear"
          "fadeLayersOut, 1, 2, almostLinear"
          "workspaces, 1, 2, almostLinear, fade"
          "workspacesIn, 1, 2, almostLinear, fade"
          "workspacesOut, 1, 2, almostLinear, fade"
        ];
      };

      # Dwindle layout
      dwindle = {
        pseudotile = true;
        preserve_split = true;
      };

      # Master layout
      master = {
        new_status = "master";
      };

      # Misc settings
      misc = {
        force_default_wallpaper = 0;
        disable_hyprland_logo = true;
      };

      # Input configuration
      input = {
        kb_layout = "us";
        kb_variant = "";
        kb_model = "";
        kb_options = "";
        kb_rules = "";
        follow_mouse = 1;
        sensitivity = 0;

        touchpad = {
          natural_scroll = false;
        };
      };

      # Gestures - TODO this was updated in 0.51.0 to be much better, need to figure those options
      # gestures = {
      #   workspace_swipe = true;
      # };

      # Key bindings
      bind = [
        # Application shortcuts
        "$mainMod, Return, exec, $terminal"
        "$mainMod, Q, killactive,"
        "$mainMod, M, exit,"
        "$mainMod, V, togglefloating,"
        "$mainMod, R, exec, $menu"
        "$mainMod, V, togglesplit,"
        "$mainMod, Z, exec, zeditor"
        "$mainMod, F, exec, zen-beta"
        "$mainMod, Period, exec, wofi-emoji"

        # Screenshots
        "$mainMod, P, exec, ~/.local/bin/screenshot-full"
        "$mainMod SHIFT, P, exec, ~/.local/bin/screenshot-region"

        # Movement
        "$mainMod, H, movefocus, l"
        "$mainMod, L, movefocus, r"
        "$mainMod, K, movefocus, u"
        "$mainMod, J, movefocus, d"

        # Workspace switching
        "$mainMod, 1, workspace, 1"
        "$mainMod, 2, workspace, 2"
        "$mainMod, 3, workspace, 3"
        "$mainMod, 4, workspace, 4"
        "$mainMod, 5, workspace, 5"
        "$mainMod, 6, workspace, 6"
        "$mainMod, 7, workspace, 7"
        "$mainMod, 8, workspace, 8"
        "$mainMod, 9, workspace, 9"
        "$mainMod, 0, workspace, 10"

        # Move window to workspace
        "$mainMod SHIFT, 1, movetoworkspace, 1"
        "$mainMod SHIFT, 2, movetoworkspace, 2"
        "$mainMod SHIFT, 3, movetoworkspace, 3"
        "$mainMod SHIFT, 4, movetoworkspace, 4"
        "$mainMod SHIFT, 5, movetoworkspace, 5"
        "$mainMod SHIFT, 6, movetoworkspace, 6"
        "$mainMod SHIFT, 7, movetoworkspace, 7"
        "$mainMod SHIFT, 8, movetoworkspace, 8"
        "$mainMod SHIFT, 9, movetoworkspace, 9"
        "$mainMod SHIFT, 0, movetoworkspace, 10"

        # Special workspace (scratchpad)
        "$mainMod, S, togglespecialworkspace, magic"
        "$mainMod SHIFT, S, movetoworkspace, special:magic"

        # Mouse workspace switching
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"
      ];

      # Mouse bindings
      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
      ];

      # Media key bindings
      bindel = [
        ",XF86AudioRaiseVolume, exec, wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"
        ",XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ",XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
        ",XF86MonBrightnessUp, exec, brightnessctl -e4 -n2 set 5%+"
        ",XF86MonBrightnessDown, exec, brightnessctl -e4 -n2 set 5%-"
      ];

      # Media control bindings
      bindl = [
        ", XF86AudioNext, exec, playerctl next"
        ", XF86AudioPause, exec, playerctl play-pause"
        ", XF86AudioPlay, exec, playerctl play-pause"
        ", XF86AudioPrev, exec, playerctl previous"
      ];

      # Window rules
      windowrule = [
        "suppressevent maximize, class:.*"
        "nofocus,class:^$,title:^$,xwayland:1,floating:1,fullscreen:0,pinned:0"
      ];

      # Force zero scaling for XWayland
      xwayland = {
        force_zero_scaling = true;
      };
    };
  };
}
