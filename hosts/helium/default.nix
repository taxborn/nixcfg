{ lib, self, ... }:

{
  imports = [
    ../../modules/nixos/server.nix
    ./disko.nix
    ./external-hdd.nix
    ./proxy.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "helium";
  system.stateVersion = "25.11";

  myNixOS = {
    programs.systemd-boot.enable = true;
    services = {
      monitoring.server.enable = true;
      paperless.enable = true;

      backups = {
        client = {
          enable = true;
          notify.enable = true;
        };
        server = {
          enable = true;
          authorizedKeys = lib.genAttrs (lib.remove "helium" (
            builtins.attrNames (import "${self}/homelab.nix").hosts
          )) (host: builtins.readFile "${self}/secrets/borg/${host}/ssh_key.pub");
        };
      };
    };
  };

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];

    loader.timeout = 0;
  };
}
