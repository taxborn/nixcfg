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
          "cpu"
          "memory"
          "battery"
          "tray"
        ];

        "hyprland/workspaces" = {
          format = "{name}: {icon}";
          format-icons = {
            active = "";
            default = "";
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
          format-muted = "";
          format-icons = {
            default = [
              ""
              ""
              " "
            ];
          };
          on-click = "pavucontrol";
        };

        cpu = {
          interval = 5;
          format = "CPU: {usage:>2}%";
        };

        memory = {
          interval = 5;
          format = "MEM: {used:0.1f}G";
        };

        tray = {
          icon-size = 16;
          spacing = 10;
        };
      };
    };
  };
}
