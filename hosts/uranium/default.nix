{
  self,
  config,
  lib,
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
    profiles.btrfs.enable = true;
    programs = {
      lanzaboote.enable = true;
      nix.enable = true;
      podman.enable = true;
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
        lokiHost = net.tailscaleIPs."helium-01";
        lokiPort = net.loki.port;
      };
      sddm.enable = true;
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
    profiles.ssd.enable = true;
  };

  boot.initrd = {
    luks = {
      # bypassWorkqueues skips dm-crypt's kcryptd read/write kworkers and
      # runs crypto inline on the submitting CPU. Much lower latency on
      # fast NVMe; visible kcryptd CPU churn goes away.
      devices."cryptroot" = {
        crypttabExtraOpts = defaultCrypttabOptions;
        bypassWorkqueues = true;
      };
      devices."crypthome" = {
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
    ];
  };

  myUsers.taxborn = {
    enable = true;
    password = "$y$j9T$23GUNNxavO/S4n8DLkfs71$ShByJUJ9XCvIs2PLYmlAjenOtpcFvnSgshjbClEKB18";
  };
}
