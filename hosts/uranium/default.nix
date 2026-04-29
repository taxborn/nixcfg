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
          "DP-3,2560x1440@165,0x0,1"
          "HDMI-A-5,1920x1080@60,2560x320,1"
        ];
      };
    };
    profiles = {
      btrfs.enable = true;
      impermanence.enable = true;
    };
    programs = {
      lanzaboote.enable = true;
      nix.enable = true;
      podman.enable = true;
      yubikey.enable = true;
    };
    services = {
      backups.client = {
        enable = false;
        enableRsyncRepo = true;
        enableHeliumRepo = true;
        desktopExcludes = true;
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
    amd.gpu.enable = true;
    profiles.ssd.enable = true;
  };

  fileSystems."/home".neededForBoot = true;

  boot.swraid.mdadmConf = "MAILADDR root";

  boot.initrd = {
    luks = {
      devices."cryptroot" = {
        crypttabExtraOpts = defaultCrypttabOptions;
        bypassWorkqueues = true;
      };
      fido2Support = false;
    };
    availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usbhid"
      "usb_storage"
      "sd_mod"
      "raid1"
      "md_mod"
    ];
  };

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };
}
