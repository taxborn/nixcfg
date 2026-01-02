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
    ./home.nix
    ./secrets.nix
    self.diskoConfigurations.luks-btrfs-tungsten
    self.nixosModules.locale-en-us
  ];

  networking.hostName = "tungsten";
  time.timeZone = "America/Chicago";
  system.stateVersion = "25.11";

  myNixOS = {
    base.enable = true;
    desktop = {
      enable = true;
      hyprland = {
        enable = true;
        laptopMonitor = "eDP-1,3456x2160@60,0x0,2";
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
    nvidia.gpu.enable = true;
    profiles = {
      ssd.enable = true;
      laptop.enable = true;
    };
  };

  hardware.nvidia.prime = {
    nvidiaBusId = "PCI:1:0:0";
    intelBusId = "PCI:0:2:0";
  };

  boot.initrd = {
    luks = {
      devices."cryptroot".crypttabExtraOpts = defaultCrypttabOptions;
      devices."crypthome".crypttabExtraOpts = defaultCrypttabOptions;
      fido2Support = false;
    };
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
