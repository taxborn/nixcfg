{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.waybar.enable = lib.mkEnableOption "Waybar status bar";

  config = lib.mkIf config.myHome.programs.waybar.enable {
    # catppuccin.waybar.mode = "createLink";
    programs.waybar = {
      enable = true;
      systemd.enable = false; # Launched via Hyprland exec-once under UWSM
      settings.bar = {
        layer = "top";
        position = "top";
        modules-left = [
          "hyprland/workspaces"
          "hyprland/window"
        ];
        modules-center = [ "clock" ];
        modules-right = [ "tray" ];
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
        }

        #workspaces button.active {
          color: @accent;
          font-weight: bold;
        }

        #workspaces button:hover {
          background: transparent;
          border: none;
        }
      '';
    };
  };
}
