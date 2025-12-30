{
  lib,
  ...
}:
let
  defaultCrypttabOptions = [
    "fido2-device=auto"
    "token-timeout=30"
  ];
in
{
  hardware.enableRedistributableFirmware = lib.mkDefault true;

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
}
