{
  pkgs,
  ...
}:

{
  imports = [
    ../common
    ../common/hyprland.nix
    ../common/secure-boot.nix

    ./hardware-configuration.nix
    ./disks.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    plymouth.enable = true;
    loader.efi.canTouchEfiVariables = true;
  };

  services.displayManager.sddm = {
    settings = {
      General = {
        GreeterEnvironment = "QT_SCREEN_SCALE_FACTORS=2,QT_FONT_DPI=192";
      };
    };
  };

  networking.hostName = "tungsten";
  time.timeZone = "America/Chicago";

  services.libinput.enable = true;

  environment.systemPackages = with pkgs; [
    brightnessctl
  ];

  system.stateVersion = "25.05";
}
