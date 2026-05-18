{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.waybar.enable = lib.mkEnableOption "Waybar status bar";

  config = lib.mkIf config.myHome.programs.waybar.enable {
    programs.waybar = {
      enable = true;
      systemd.enable = false; # Launched via Hyprland exec-once under UWSM

      settings.mainBar = {
        layer = "top";
        position = "top";
        height = 30;
        spacing = 4;

        modules-left = [
          "hyprland/workspaces"
          "hyprland/window"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "pulseaudio"
          "network"
          "battery"
          "tray"
        ];

        "hyprland/workspaces" = {
          format = "{name}";
          on-click = "activate";
        };

        clock = {
          format = "{:%a %Y-%m-%d  %H:%M}";
          tooltip-format = "<tt><small>{calendar}</small></tt>";
        };

        battery = {
          states = {
            warning = 30;
            critical = 15;
          };
          format = "{capacity}% {icon}";
          format-charging = "{capacity}% ";
          format-plugged = "{capacity}% ";
          format-icons = [
            ""
            ""
            ""
            ""
            ""
          ];
        };

        network = {
          format-wifi = "{essid} ({signalStrength}%) ";
          format-ethernet = "{ipaddr} ";
          format-disconnected = "disconnected ⚠";
          tooltip-format = "{ifname}: {ipaddr}";
        };

        pulseaudio = {
          format = "{volume}% {icon}";
          format-muted = "muted ";
          format-icons.default = [
            ""
            ""
            ""
          ];
          on-click = "pavucontrol";
        };

        tray.spacing = 8;
      };

      style = ''
        * {
          font-family: "JetBrainsMono Nerd Font", monospace;
          font-size: 12px;
        }
        window#waybar {
          background: rgba(30, 30, 46, 0.9);
          color: #cdd6f4;
        }
        #workspaces button {
          padding: 0 8px;
          color: #cdd6f4;
          background: transparent;
        }
        #workspaces button.active {
          background: #45475a;
          border-radius: 4px;
        }
        #clock, #battery, #network, #pulseaudio, #tray {
          padding: 0 10px;
        }
        #battery.warning  { color: #f9e2af; }
        #battery.critical { color: #f38ba8; }
      '';
    };
  };
}
