{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.services.waybar.enable = lib.mkEnableOption "waybar";

  config = lib.mkIf config.myHome.services.waybar.enable {
    # TODO: How should I handle fonts for the entire home
    home.packages = with pkgs; [
      # Nerd fonts
      nerd-fonts.jetbrains-mono

      # noto
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji

      # Accessible fonts
      atkinson-hyperlegible-next
      atkinson-hyperlegible-mono

    ];
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      style = ./styles.css;
      settings = {
        mainBar = {
          layer = "top";
          position = "bottom";
          modules-left = [ "hyprland/workspaces" ];
          modules-right = [
            "pulseaudio"
            "cpu"
            "memory"
            "backlight"
            "battery"
            "clock"
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
            format = "{:%H:%M}";
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
            format = " {usage:>2}%";
          };

          memory = {
            interval = 5;
            format = " {used:0.1f}G";
          };

          tray = {
            icon-size = 16;
            spacing = 10;
          };
        };
      };
    };

    systemd.user.services.waybar = {
      Install.WantedBy = lib.mkForce (
        lib.optional config.wayland.windowManager.hyprland.enable "hyprland-session.target"
      );

      Service.Restart = lib.mkForce "no";

      Unit.BindsTo = lib.optional config.wayland.windowManager.hyprland.enable "hyprland-session.target";
    };
  };
}
