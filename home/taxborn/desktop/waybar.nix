{ pkgs, ... }:

{
  programs.waybar = {
    enable = true;
    systemd.enable = true;
    style = ./waybar.css;
    settings = {
      mainBar = {
        layer = "top";
        position = "top";
        modules-left = [ "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [
          "pulseaudio"
          "network"
          "cpu"
          "memory"
          "tray"
        ];

        "hyprland/workspaces" = {
          format = "{name}: {icon}";
          format-icons = {
            active = "";
            default = "";
          };
        };

        clock = {
          timezone = "America/Chicago";
          tooltip-format = "{:%Y-%m-%dT%H:%M:%S%z}";
          format = "{:%Y/%m/%d - %H:%M:%S}";
          interval = 1;
        };

        pulseaudio = {
          format = "{icon} {volume}%";
          format-muted = "";
          format-icons = {
            default = [
              ""
              ""
              " "
            ];
          };
          on-click = "pavucontrol";
        };

        network = {
          format-wifi = "󰤢";
          format-ethernet = "󰈀";
          format-disconnected = "󰤠";
          interval = 5;
          tooltip = false;
        };

        cpu = {
          interval = 1;
          format = "  {icon0}{icon1}{icon2}{icon3} {usage:>2}%";
          format-icons = [
            "▁"
            "▂"
            "▃"
            "▄"
            "▅"
            "▆"
            "▇"
            "█"
          ];
        };

        memory = {
          interval = 30;
          format = "  {used:0.1f}G/{total:0.1f}G";
        };

        tray = {
          icon-size = 16;
          spacing = 10;
        };
      };
    };
  };
}
