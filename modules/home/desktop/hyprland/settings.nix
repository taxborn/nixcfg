{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myHome;

  defaultApps = {
    terminal = cfg.profiles.defaultApps.terminal.exec or (lib.getExe pkgs.ghostty);
    webBrowser =
      cfg.profiles.defaultApps.webBrowser.exec or (lib.getExe config.programs.firefox.finalPackage);
    fileManager = cfg.profiles.defaultApps.fileManager.exec or (lib.getExe pkgs.nemo);
    editor = cfg.profiles.defaultApps.editor.exec or (lib.getExe pkgs.gnome-text-editor);
  };

  scripts = import ./scripts.nix { inherit config lib pkgs; };
  helpers = import ./helpers.nix { inherit config lib pkgs; };

  windowManagerBinds = {
    Down = "down";
    Left = "left";
    Right = "right";
    Up = "up";
    H = "left";
    J = "down";
    K = "up";
    L = "right";
  };
in
{
  "$mod" = "SUPER";

  animations = {
    enabled = true;
    bezier = "myBezier,0.05,0.9,0.1,1.05";

    animation = [
      "border,1,10,default"
      "borderangle,1,8,default"
      "fade,1,7,default"
      "specialWorkspace,1,6,default,slidevert"
      "windows,1,7,myBezier"
      "windowsOut,1,7,default,popin 80%"
      "workspaces,1,6,default"
    ];
  };

  bind = [
    "$mod,Return,exec,${defaultApps.terminal}"
    "$mod,B,exec,${defaultApps.webBrowser}"
    "$mod,E,exec,${defaultApps.editor}"
    "$mod,F,exec,${defaultApps.fileManager}"

    ",PRINT,exec,${lib.getExe helpers.screenshot}"
    "CTRL,F12,exec,${lib.getExe helpers.screenshot}"
    "$mod, L,exec,${lib.getExe' pkgs.systemd "loginctl"} lock-session"
    "$mod SHIFT,backslash,togglesplit"

    "$mod SHIFT,comma,exec,${lib.getExe pkgs.hyprnome} --previous --move"
    "$mod SHIFT,period,exec,${lib.getExe pkgs.hyprnome} --move"
    "$mod,comma,exec,${lib.getExe pkgs.hyprnome} --previous"
    "$mod,period,exec,${lib.getExe pkgs.hyprnome}"

    "$mod SHIFT,S,movetoworkspace,special:magic"
    "$mod SHIFT,V,togglefloating"
    "$mod SHIFT,W,fullscreen"
    "$mod,Q,killactive"

    "$mod,R,exec,${lib.getExe config.programs.rofi.package} -show drun"
    "$mod SHIFT,R,exec,${lib.getExe pkgs.rofi-rbw}"

    "$mod,F11,exec,pkill -SIGUSR1 waybar"
    "$mod,Left,changegroupactive,b"
    "$mod,Right,changegroupactive,f"
    "$mod,S,togglespecialworkspace,magic"
  ]
  ++ builtins.map (x: "$mod SHIFT,${toString x},movetoworkspace,${toString x}") [
    1
    2
    3
    4
    5
    6
    7
    8
    9
  ]
  ++ builtins.map (x: "$mod,${toString x},workspace,${toString x}") [
    1
    2
    3
    4
    5
    6
    7
    8
    9
  ]
  ++ lib.attrsets.mapAttrsToList (
    key: direction:
    "$mod CTRL SHIFT,${key},movecurrentworkspacetomonitor,${builtins.substring 0 1 direction}"
  ) windowManagerBinds
  ++ lib.attrsets.mapAttrsToList (
    key: direction: "$mod SHIFT,${key},movewindow,${builtins.substring 0 1 direction}"
  ) windowManagerBinds
  ++ lib.attrsets.mapAttrsToList (
    key: direction: "$mod,${key},movefocus,${builtins.substring 0 1 direction}"
  ) windowManagerBinds;

  bindm = [
    # Move/resize windows with mainMod + LMB/RMB and dragging
    "$mod,mouse:272,movewindow"
    "$mod,mouse:273,resizewindow"
  ];

  bindl = [
    # Volume, microphone, and media keys.
    "$mod,xf86audiomute,exec,${helpers.media.play}"
    "$mod,xf86audioprev,exec,${helpers.media.prev}"
    "$mod,xf86audionext,exec,${helpers.media.next}"
    ",xf86audiomute,exec,${helpers.volume.mute}"
    ",xf86audiomicmute,exec,${helpers.volume.micMute}"
    ",xf86audioplay,exec,${helpers.media.play}"
    ",xf86audioprev,exec,${helpers.media.prev}"
    ",xf86audionext,exec,${helpers.media.next}"
  ]
  ++ lib.lists.optionals (cfg.desktop.hyprland.laptopMonitor != null) [
    ",switch:on:Lid Switch,exec,${scripts.clamshell} on"
    ",switch:off:Lid Switch,exec,${scripts.clamshell} off"
  ];

  bindle = [
    # Display, volume, microphone, and media keys.
    ",xf86monbrightnessup,exec,${helpers.brightness.up}"
    ",xf86monbrightnessdown,exec,${helpers.brightness.down}"
    ",xf86audioraisevolume,exec,${helpers.volume.up}"
    ",xf86audiolowervolume,exec,${helpers.volume.down}"
  ];

  decoration = {
    blur.enabled = false;
    dim_special = 0.5;
    rounding = 0;
    shadow.enabled = false;
  };

  dwindle.preserve_split = true;

  input = {
    focus_on_close = 1;
    follow_mouse = 1;
    sensitivity = 0; # -1.0 to 1.0, 0 means no modification.

    touchpad = {
      clickfinger_behavior = true;
      drag_lock = true;
      middle_button_emulation = true;
      natural_scroll = true;
      tap-to-click = true;
    };
  };

  general = {
    allow_tearing = false;
    border_size = 0;
    gaps_in = 5;
    gaps_out = 6;
    layout = "dwindle";
  };

  gesture = [
    "3,horizontal,workspace"
    "4,horizontal,workspace"
  ];

  group = {
    groupbar = {
      height = 24;
      gradients = true;
    };
  };

  misc = {
    disable_hyprland_logo = true;
    disable_splash_rendering = true;
    enable_anr_dialog = false;
    enable_swallow = true;
    focus_on_activate = true;
    key_press_enables_dpms = true;
    mouse_move_enables_dpms = true;
    swallow_regex = "^(Alacritty|kitty|footclient|foot|com\.mitchellh\.ghostty|org\.wezfurlong\.wezterm|codium|code)$";
    vfr = true;
  };

  monitor = [
    ",preferred,auto,auto"
  ]
  ++ cfg.desktop.hyprland.monitors
  ++ lib.lists.optional (
    cfg.desktop.hyprland.laptopMonitor != null
  ) cfg.desktop.hyprland.laptopMonitor;

  xwayland.force_zero_scaling = true;
}
