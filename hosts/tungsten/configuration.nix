{
  pkgs,
  ...
}:

{
  imports = [
    ../common
    ../common/hyprland.nix

    ./hardware-configuration.nix
    ./disks.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    plymouth.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  services.displayManager.sddm = {
    settings = {
      General = {
        GreeterEnvironment = "QT_SCREEN_SCALE_FACTORS=2,QT_FONT_DPI=192";
      };
    };
  };

  extraServices = {
    virtualisation.enable = true;
    secure-boot.enable = true;
  };

  networking.hostName = "tungsten";
  time.timeZone = "America/Chicago";

  services.libinput.enable = true;

  environment.systemPackages = with pkgs; [
    brightnessctl
    pavucontrol
  ];

  system.stateVersion = "25.05";
}
