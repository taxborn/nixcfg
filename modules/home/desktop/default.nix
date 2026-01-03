{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./hyprland
  ];

  options.myHome.desktop.enable = lib.mkOption {
    default = config.myHome.desktop.hyprland.enable;
    description = "Desktop environment configuration.";
    type = lib.types.bool;
  };

  config = lib.mkIf config.myHome.desktop.enable {
    home.packages = [
      pkgs.adwaita-icon-theme
      pkgs.liberation_ttf
    ];

    dconf = {
      enable = true;

      settings = {
        "org/gnome/nm-applet".disable-connected-notifications = true;
        "org/gtk/gtk4/settings/file-chooser".sort-directories-first = true;
        "org/gtk/settings/file-chooser".sort-directories-first = true;
      };
    };

    gtk.gtk3.bookmarks = [
      "file://${config.xdg.userDirs.documents}"
      "file://${config.xdg.userDirs.download}"
      "file://${config.xdg.userDirs.music}"
      "file://${config.xdg.userDirs.videos}"
      "file://${config.xdg.userDirs.pictures}"
    ];

    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      desktop = lib.mkDefault "${config.home.homeDirectory}/desktop";
      documents = lib.mkDefault "${config.home.homeDirectory}/documents";
      download = lib.mkDefault "${config.home.homeDirectory}/downloads";
      music = lib.mkDefault "${config.home.homeDirectory}/media/music";
      pictures = lib.mkDefault "${config.home.homeDirectory}/media/photos";
      videos = lib.mkDefault "${config.home.homeDirectory}/media/video";
      templates = lib.mkDefault "${config.home.homeDirectory}/templates";
      publicShare = lib.mkDefault "${config.home.homeDirectory}/public";
    };
  };
}
