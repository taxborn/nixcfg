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
      settings.bar = {
        layer = "top";
        position = "top";

        modules-left = [
          # TODO: Can't select workspaces, suspect something to do with new dispatch/lua setup
          "hyprland/workspaces"
          "hyprland/window"
        ];
        modules-center = [ "clock" ];
        modules-right = [ "tray" ];

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
          format = "{:%H:%M}";
          interval = 1;
        };
      };
      style = ''
        * {
          border: none;
          font-family: "JetBrainsMono NFM", monospace;
          font-size: 12px;
        }

        window#waybar {
          background-color: @surface0;
          color: @text;
          border-bottom: 2px solid @accent;
        }

        #workspaces button {
          color: @text;
          box-shadow: none;
          text-shadow: none;
          transition: none;
        }

        #workspaces button.active {
          color: @accent;
          font-weight: bold;
        }

        #workspaces button:hover {
          background: transparent;
        }
      '';
    };
  };
}
