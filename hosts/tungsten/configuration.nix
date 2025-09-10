{
  pkgs,
  ...
}:

{
  imports = [
    ../common

    ./hardware-configuration.nix
    ./disks.nix
  ];

  boot = {
    kernelPackages = pkgs.linuxPackages_latest;
    # Enable "Silent boot"
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
    ];
    loader = {
      timeout = 0;
      efi.canTouchEfiVariables = true;
    };
    plymouth = {
      enable = true;
    };
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    settings = {
      General = {
        GreeterEnvironment = "QT_SCREEN_SCALE_FACTORS=2,QT_FONT_DPI=192";
      };
    };
  };

  networking.hostName = "tungsten";
  time.timeZone = "America/Chicago";

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  services.libinput.enable = true;
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  environment.systemPackages = with pkgs; [
    brightnessctl
  ];

  system.stateVersion = "25.05";
}
