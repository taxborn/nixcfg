{
  self,
  config,
  ...
}:
let
  defaultCrypttabOptions = [
    "fido2-device=auto"
    "token-timeout=30"
  ];
  net = config.mySnippets.mischief-town.networkMap;
in
{
  imports = [
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
    profiles.btrfs.enable = true;
    programs = {
      lanzaboote.enable = true;
      nix.enable = true;
      yubikey.enable = true;
    };
    services = {
      backups.client = {
        enable = true;
        enableRsyncRepo = true;
        enableHeliumRepo = true;
        desktopExcludes = true;
      };
      node-exporter.enable = true;
      fluent-bit = {
        enable = true;
        lokiHost = net.tailscaleIPs.helium-01;
        lokiPort = net.loki.port;
      };
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
