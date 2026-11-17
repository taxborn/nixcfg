{
  imports = [
    ../../modules/nixos/services/monitoring/server.nix
    ../../modules/nixos/services/paperless.nix
    ../../modules/nixos/server.nix
    ./disko.nix
    ./external-hdd.nix
    ./proxy.nix
  ];

  nixpkgs.hostPlatform = "x86_64-linux";
  networking.hostName = "helium";
  system.stateVersion = "25.11";

  boot = {
    initrd.availableKernelModules = [
      "xhci_pci"
      "ahci"
      "nvme"
      "usb_storage"
      "sd_mod"
      "rtsx_pci_sdmmc"
    ];

    loader = {
      timeout = 0;
      efi.canTouchEfiVariables = true;
      systemd-boot = {
        enable = true;
        configurationLimit = 10;
      };
    };
  };
}
