{
  config,
  lib,
  modulesPath,
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
    (modulesPath + "/installer/scan/not-detected.nix")
  ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "nvme"
    "usb_storage"
    "sd_mod"
    "rtsx_pci_sdmmc"
  ];
  boot.initrd.luks = {
    devices."cryptroot".crypttabExtraOpts = defaultCrypttabOptions;
    devices."crypthome".crypttabExtraOpts = defaultCrypttabOptions;
    fido2Support = false;
  };
  boot.initrd = {
    supportedFilesystems = [ "btrfs" ];
    systemd.enable = true;
  };
  boot.kernelModules = [ "kvm-intel" ];

  # TODO: is this needed?
  networking.useDHCP = lib.mkDefault true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
}
