{
  config,
  lib,
  ...
}:
{
  options.myHardware.profiles.ovh.enable = lib.mkEnableOption "OVH server modules";

  config = lib.mkIf config.myHardware.profiles.ovh.enable {
    boot.initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "virtio_scsi"
    ];
  };
}
