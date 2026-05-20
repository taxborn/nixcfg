{
  self,
  ...
}:
{
  imports = [
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.luks-btrfs-uranium
  ];

  networking.hostName = "uranium";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  myNixOS = {
    profiles.workstation.enable = true;
    desktop.hyprland.monitors = [
      "DP-3,2560x1440@165,0x0,1"
      "HDMI-A-5,1920x1080@60,2560x320,1"
    ];
    services.greetd.primaryOutput = "DP-3";
  };

  boot.initrd.availableKernelModules = [
    "ahci"
    "usbhid"
  ];

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  hardware.steam-hardware.enable = true;

  myHardware = {
    amd.gpu.enable = true;
    intel.cpu.enable = true;
  };
}
