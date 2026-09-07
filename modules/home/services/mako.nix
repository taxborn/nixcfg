{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.services.mako.enable = lib.mkEnableOption "mako notification daemon";

  config = lib.mkIf config.myHome.services.mako.enable {
    home.packages = [
      pkgs.libnotify
    ];
    services.mako = {
      enable = true;

      settings = {
        border-radius = "10";
        default-timeout = "10000";
        group-by = "app-name";
        height = "300";
        icon-path = "${pkgs.papirus-icon-theme}/share/icons/Papirus/";
        margin = "10,0";
        outer-margin = "10";
        padding = "10";
        width = "400";
      };
    };

    # Home Manager configures Mako and registers its D-Bus package, but does
    # not create a user unit. Start it with Hyprland and stop it when that
    # session disappears. Type=dbus waits for the notification bus name.
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
        ExecReload = "${lib.getExe' pkgs.mako "makoctl"} reload";
        ExecStart = "${lib.getExe pkgs.mako}";
        Restart = "on-failure";
        RestartSec = 5;
        Type = "dbus";
      };

      Install.WantedBy = lib.optional config.wayland.windowManager.hyprland.enable "hyprland-session.target";
    };
  };
}
