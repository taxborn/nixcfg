{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
let
  cfg = config.myHome.desktop.hyprland;
  isLaptop = osConfig.myHardware.profiles.laptop.enable or false;
  decorationConfig =
    if isLaptop then
      ''
        hl.config({
            decoration = {
                inactive_opacity = 1.0,

                shadow = {
                    enabled = false,
                },

                blur = {
                    enabled = false,
                },
            },
        })''
    else
      ''
        hl.config({
            decoration = {
                -- Change transparency of unfocused windows on desktops
                inactive_opacity = 0.90,

                shadow = {
                    enabled = true,
                },

                blur = {
                    enabled = true,
                },
            },
        })'';
in
{
  options.myHome.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland home-manager configuration";
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      grim
      playerctl
      slurp
      wl-clipboard
    ];

    home.pointerCursor = {
      enable = true;
      package = pkgs.catppuccin-cursors.mochaMauve;
      name = "catppuccin-mocha-mauve-cursors";
      size = 24;
      gtk.enable = true;
      x11.enable = true;
      hyprcursor.enable = true;
    };

    wayland.windowManager.hyprland = {
      enable = true;
      xwayland.enable = true;
      systemd = {
        enable = true;
        variables = [ "--all" ];
      };
      configType = "lua";
      # Written beside the generated `hyprland.lua`, which `require()`s each of
      # them for us. `extraConfig` is emitted after those requires, so the
      # per-machine decoration overrides win.
      extraLuaFiles = {
        animations = ./config/animations.lua;
        decorations = ./config/decorations.lua;
        keybinds = ./config/keybinds.lua;
        monitors = ./config/monitors.lua;
        rules = ./config/rules.lua;
        session = ./config/session.lua;
      };
      extraConfig = decorationConfig;
    };

    xdg.configFile."hypr/hyprpaper.conf".source = ./config/hyprpaper.conf;
  };
}
