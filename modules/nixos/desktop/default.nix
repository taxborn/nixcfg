{
  lib,
  config,
  pkgs,
  ...
}:
let
  bluemanBin = "${pkgs.blueman}/bin/blueman-applet";
in
{
  imports = [
    ./hyprland
  ];

  options.myNixOS.desktop.enable = lib.mkEnableOption "minimal graphical desktop configuration";

  config = lib.mkIf config.myNixOS.desktop.enable {
    environment.sessionVariables.NIXOS_OZONE_WL = "1";
    boot.kernelPackages = pkgs.linuxPackages_latest;
    hardware.logitech.wireless = {
      enable = true;
      enableGraphical = true;
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

    # services.blueman generates a drop-in with ExecStart= that conflicts with
    # the base unit's ExecStart. Clear it first so systemd sees only one.
    systemd.user.services.blueman-applet.serviceConfig.ExecStart =
      lib.mkIf config.hardware.bluetooth.enable
        (
          lib.mkForce [
            ""
            bluemanBin
          ]
        );

    myNixOS.profiles = {
      audio.enable = true;
      graphical-boot.enable = true;
    };
  };
}
