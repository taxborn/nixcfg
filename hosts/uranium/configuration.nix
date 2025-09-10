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
      systemd-boot = {
        configurationLimit = 10;
      };
    };
    plymouth = {
      enable = true;
    };
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  networking.hostName = "uranium";
  time.timeZone = "America/Chicago";

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  system.stateVersion = "25.05";
}
