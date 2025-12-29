{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.desktop.hyprland = {
    enable = lib.mkEnableOption "hyprland desktop environment";

    laptopMonitor = lib.mkOption {
      description = "Internal laptop monitor.";
      default = null;
      type = lib.types.nullOr lib.types.str;
    };

    monitors = lib.mkOption {
      description = "List of external monitors.";
      default = [ ];
      type = lib.types.listOf lib.types.str;
    };
  };

  config = lib.mkIf config.myHome.desktop.hyprland.enable {
    home.packages = with pkgs; [
      libnotify
      networkmanagerapplet
    ];

    programs.firefox.enable = true;

    services = {
      gnome-keyring.enable = true;
    };

    systemd.user.services.polkit-gnome-authentication-agent = {
      Unit = {
        After = "graphical-session.target";
        BindsTo = [ "hyprland-session.target" ];
        Description = "PolicyKit authentication agent from GNOME.";
        PartOf = "graphical-session.target";
      };

      Service = {
        ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
        Restart = "no";
      };

      Install.WantedBy = [ "hyprland-session.target" ];
    };

    wayland.windowManager.hyprland = {
      enable = true;
      settings = import ./settings.nix { inherit config lib pkgs; };

      systemd = {
        enable = true;
        variables = [ "--all" ];
      };
    };

    xdg.portal = {
      enable = true;
      configPackages = [ pkgs.xdg-desktop-portal-hyprland ];

      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-hyprland
      ];
    };

    myHome = {
      desktop.enable = true;
      programs.rofi.enable = true;

      services = {
        hypridle.enable = true;
        waybar.enable = true;
      };
    };
  };
}
