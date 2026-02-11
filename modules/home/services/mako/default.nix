{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.services.mako.enable = lib.mkEnableOption "mako notification daemon";

  config = lib.mkIf config.myHome.services.mako.enable {
    home.packages = [ pkgs.mpv ];
    services.mako = {
      enable = true;

      settings = {
        actions = "true";
        anchor = "top-right";
        border-radius = "10";
        border-size = "2";

        background-color = "#1e1e2e";
        text-color = "#cdd6f4";
        border-color = "#cba6f7";
        progress-color = "#a6e3a1";

        default-timeout = "10000";
        group-by = "app-name";
        height = "300";
        icon-path = "${pkgs.papirus-icon-theme}/share/icons/Papirus/";
        icons = "true";
        layer = "top";
        margin = "10,0";
        outer-margin = "10";
        padding = "10";
        sort = "-time";
        width = "400";
      };
    };

    systemd.user.services.mako = {
      Unit = {
        After = "graphical-session.target";
        BindsTo = lib.optional config.wayland.windowManager.hyprland.enable "hyprland-session.target";
        Description = "Lightweight Wayland notification daemon";
        Documentation = "man:mako(1)";
        PartOf = "graphical-session.target";
      };

      Service = {
        BusName = "org.freedesktop.Notifications";
        Environment = [
          "PATH=${
            lib.makeBinPath [
              pkgs.bash
              pkgs.mpv
            ]
          }"
        ];
        ExecReload = "${lib.getExe' pkgs.mako "makoctl"} reload";
        ExecStart = "${lib.getExe pkgs.mako}";
        Restart = lib.mkForce "no";
        Type = "dbus";
      };

      Install.WantedBy = lib.optional config.wayland.windowManager.hyprland.enable "hyprland-session.target";
    };
  };
}
