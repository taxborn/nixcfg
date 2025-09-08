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
      systemd-boot.enable = true;
      # for some silly reason grub doesn't work on Uranium. maybe can't create
      # efi variables easily?
      # grub = {
      #   enable = true;
      #   efiSupport = true;
      #   device = "nodev";
      # };
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

  # services.libinput.enable = true;
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  environment.systemPackages = with pkgs; [
    wofi
    nixfmt-rfc-style
  ];

  system.stateVersion = "25.05";
}
