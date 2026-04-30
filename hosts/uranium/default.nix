{
  self,
  ...
}:
{
  imports = [
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.luks-btrfs-uranium
    self.nixosModules.locale-en-us
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
    programs.podman.enable = true;
  };

  myHardware = {
    intel.cpu.enable = true;
    amd.gpu.enable = true;
  };

  services.pipewire.wireplumber.extraConfig."10-default-audio-sink" = {
    "wireplumber.settings" = {
      "default.audio.sink" = "alsa_output.pci-0000_03_00.1.hdmi-stereo-extra3";
    };
  };

  boot.initrd.luks.devices."cryptroot".bypassWorkqueues = true;

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "ahci"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "raid1"
    "md_mod"
  ];
}
