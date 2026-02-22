{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myHome;
  scale = cfg.services.hypridle.hyprlockScale;
  sp = n: toString (n * scale);
in
{
  options.myHome.services.hypridle = {
    enable = lib.mkEnableOption "hypridle idle/lock manager";

    autoSuspend = lib.mkOption {
      description = "Whether to autosuspend on idle.";
      default = true;
      type = lib.types.bool;
    };

    hyprlockScale = lib.mkOption {
      description = "Scale factor for hyprlock UI elements. Set to 2 for HiDPI displays where hyprlock renders at physical pixels.";
      default = 1;
      type = lib.types.int;
    };
  };

  config = lib.mkIf cfg.services.hypridle.enable {
    programs.hyprlock = {
      enable = true;

      settings = {
        general = {
          no_fade_in = false;
          no_fade_out = false;
          hide_cursor = false;
          grace = 0;
          disable_loading_bar = false;
        };

        background = {
          path = "/home/taxborn/media/photos/all-catppuccin-mandelbrot/mandelbrot_full_magenta.png";
          blur_passes = 2;
          contrast = 1;
          brightness = 0.6;
          vibrancy = 0.2;
          vibrancy_darkness = 0.2;
        };

        input-field = {
          rounding = 32 * scale;
          outline_thickness = 2 * scale;
          size = "${sp 250}, ${sp 50}";
          dots_size = 0.2;
          dots_spacing = 0.35;
          outer_color = "rgba(0, 0, 0, 0)";
          inner_color = "rgba(0, 0, 0, 0.2)";
          font_color = "rgb(205, 214, 244)";
          fade_on_empty = false;
          position = "0, -${sp 400}";
          halign = "center";
          valign = "center";
        };

        label = [
          {
            text = "cmd[update:1000] echo \"$(date +\"%A, %B %d\")\"";
            color = "rgba(205, 214, 244, 0.75)";
            font_size = 22 * scale;
            font_family = "JetBrains Mono";
            position = "0, ${sp 300}";
            halign = "center";
            valign = "center";
          }
          {
            text = "cmd[update:1000] echo \"$(date +\"%-H:%M\")\"";
            color = "rgba(205, 214, 244, 0.75)";
            font_size = 95 * scale;
            font_family = "JetBrains Mono Extrabold";
            position = "0, ${sp 200}";
            halign = "center";
            valign = "center";
          }
        ];
      };
    };

    services.hypridle = {
      enable = true;

      settings = {
        general = {
          after_sleep_cmd = "hyprctl dispatch dpms on";
          lock_cmd = "pidof hyprlock || hyprlock --immediate --no-fade-in";
          before_sleep_cmd = "loginctl lock-session";
        };

        listener = [
          {
            timeout = 30;
            on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -sd *::kbd_backlight set 0";
            on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -rd *::kbd_backlight";
          }
          {
            timeout = 120;
            on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -s set 10";
            on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -r";
          }
          {
            timeout = 300;
            on-timeout = "loginctl lock-session";
          }
          {
            timeout = 360;
            on-timeout = "hyprctl dispatch dpms off";
            on-resume = "hyprctl dispatch dpms on";
          }
        ]
        ++ lib.optional cfg.services.hypridle.autoSuspend {
          timeout = 600;
          on-timeout = "systemctl suspend";
        };
      };
    };

    systemd.user.services = {
      hypridle = {
        Install.WantedBy = lib.mkForce (
          lib.optional config.wayland.windowManager.hyprland.enable "hyprland-session.target"
        );

        Service = {
          Environment = lib.mkForce [
            "PATH=${
              lib.makeBinPath (
                (with pkgs; [
                  bash
                  brightnessctl
                  hyprlock
                  systemd
                  uutils-coreutils-noprefix
                ])
                ++ lib.optional config.wayland.windowManager.hyprland.enable config.wayland.windowManager.hyprland.package
              )
            }"
          ];

          Restart = lib.mkForce "no";
        };

        Unit.BindsTo = lib.optional config.wayland.windowManager.hyprland.enable "hyprland-session.target";
      };

      pipewire-inhibit-idle = {
        Unit = {
          After = "graphical-session.target";
          BindsTo = lib.optional config.wayland.windowManager.hyprland.enable "hyprland-session.target";
          Description = "inhibit idle when audio is playing with Pipewire.";
          PartOf = "graphical-session.target";
        };

        Service = {
          ExecStart = lib.getExe pkgs.wayland-pipewire-idle-inhibit;
          Restart = "no";
        };

        Install.WantedBy = lib.optional config.wayland.windowManager.hyprland.enable "hyprland-session.target";
      };
    };
  };
}
