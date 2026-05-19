{
  lib,
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./hyprland
  ];

  options.myNixOS.desktop.enable = lib.mkEnableOption "minimal graphical desktop configuration";

  config = lib.mkIf config.myNixOS.desktop.enable {
    environment = {
      sessionVariables.NIXOS_OZONE_WL = "1";
      systemPackages = [ pkgs.age-plugin-yubikey ];
    };
    boot.kernelPackages = pkgs.linuxPackages_latest;
    hardware = {
      logitech.wireless = {
        enable = true;
        enableGraphical = true;
      };
      keyboard.qmk.enable = true;
    };

    home-manager.sharedModules = [
      {
        config.myHome.desktop.enable = true;
      }
    ];

    services = {
      blueman.enable = lib.mkIf config.hardware.bluetooth.enable true;
      gnome.gnome-keyring.enable = true;
      gvfs.enable = true; # Mount, trash, etc.
      libinput.enable = true;
    };

    myNixOS.profiles = {
      audio.enable = true;
      graphical-boot.enable = true;
      bluetooth.enable = true;
    };
  };
}
