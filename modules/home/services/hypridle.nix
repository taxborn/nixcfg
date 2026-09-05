{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myHome;
in
{
  options.myHome.services.hypridle = {
    enable = lib.mkEnableOption "hypridle idle/lock manager";

    autoSuspend = lib.mkOption {
      description = ''
        Keep the last step of the idle ladder, `systemctl suspend` at ten
        minutes. Turning it off leaves the earlier ones in place: the screen
        still locks at five minutes and blanks at six.
      '';
      default = true;
      type = lib.types.bool;
    };

    kbdBacklight = lib.mkOption {
      description = ''
        Dim the keyboard backlight after 30 seconds. Off where there is no
        `*::kbd_backlight` device for brightnessctl to find, which is every
        desktop.
      '';
      default = true;
      type = lib.types.bool;
    };
  };

  config = lib.mkIf cfg.services.hypridle.enable {
    programs.hyprlock = {
      enable = true;

      settings = {
        background = {
          path = "/home/taxborn/media/photos/wallpapers/pexels-alberlan-7311921.jpg";
          blur_passes = 2;
          contrast = 1;
          brightness = 0.6;
          vibrancy = 0.2;
          vibrancy_darkness = 0.2;
        };
      };
    };

    services.hypridle = {
      enable = true;

      settings = {
        # Three things lock this session: the idle listener below,
        # `before_sleep_cmd`, and the SUPER+SHIFT+L bind in the hyprland
        # config. All three ask logind, and logind comes back here to
        # `lock_cmd`, which is why the `pidof` guard only has to exist once.
        # Without it a second request stacks another hyprlock on the first.
        general = {
          after_sleep_cmd = "hyprctl dispatch dpms on";
          lock_cmd = "pidof hyprlock || hyprlock --no-fade-in";
          before_sleep_cmd = "loginctl lock-session";
        };

        listener =
          lib.optional cfg.services.hypridle.kbdBacklight {
            timeout = 30;
            on-timeout = "${pkgs.brightnessctl}/bin/brightnessctl -sd *::kbd_backlight set 0";
            on-resume = "${pkgs.brightnessctl}/bin/brightnessctl -rd *::kbd_backlight";
          }
          ++ [
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
                  procps
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
