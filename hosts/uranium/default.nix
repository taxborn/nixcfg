{
  lib,
  self,
  pkgs,
  ...
}:
let
  defaultCrypttabOptions = [
    "fido2-device=auto"
    "token-timeout=30"
  ];
in
{
  imports = [
    ./backup.nix
    ./hardware.nix
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.luks-btrfs-uranium
    self.nixosModules.locale-en-us
  ];

  networking.hostName = "uranium";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  myNixOS = {
    base.enable = true;
    desktop = {
      enable = true;
      hyprland = {
        enable = true;
        monitors = [
          "DP-5,2560x1440@165,0x0,1"
          "HDMI-A-5,1920x1080@60,2560x320,1"
        ];
      };
    };
    profiles = {
      btrfs.enable = true;
    };
    programs = {
      firefox.enable = true;
      nix.enable = true;
      lanzaboote.enable = true;
      yubikey.enable = true;
    };
    services = {
      sddm = {
        enable = true;
        autoLogin = "taxborn";
      };
      tailscale = {
        enable = true;
        operator = "taxborn";
      };
    };
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true; # Open ports in the firewall for Steam Remote Play
    dedicatedServer.openFirewall = true; # Open ports in the firewall for Source Dedicated Server
  };

  myHardware = {
    intel.cpu.enable = true;
    amd.gpu.enable = true;
    profiles = {
      ssd.enable = true;
    };
  };

  hardware.enableRedistributableFirmware = lib.mkDefault true;
  hardware.nvidia.prime = {
    nvidiaBusId = "PCI:0:2:0";
    intelBusId = "PCI:1:0:0";
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd = {
    luks = {
      devices."cryptroot".crypttabExtraOpts = defaultCrypttabOptions;
      devices."crypthome".crypttabExtraOpts = defaultCrypttabOptions;
      fido2Support = false;
    };
    systemd.enable = true;
    availableKernelModules = [
      "xhci_pci"
      "thunderbolt"
      "nvme"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];
  };

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };
}
