{
  self,
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
      impermanence.enable = true;
    };
    programs = {
      lanzaboote.enable = true;
      nix.enable = true;
      yubikey.enable = true;
    };
    services = {
      backups.client = {
        enable = false;
        enableRsyncRepo = true;
        enableHeliumRepo = true;
        desktopExcludes = true;
        # managed by Obsidian sync, no need to back up
        extraExcludes = [ "/home/taxborn/documents/notes" ];
      };
      sddm.enable = true;
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

  fileSystems."/home".neededForBoot = true;

  boot.swraid.mdadmConf = "MAILADDR root";

  boot.initrd = {
    luks = {
      devices."cryptroot".crypttabExtraOpts = defaultCrypttabOptions;
      fido2Support = false;
    };
    availableKernelModules = [
      "xhci_pci"
      "thunderbolt"
      "nvme"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
      "raid1"
      "md_mod"
    ];
  };

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };
}
