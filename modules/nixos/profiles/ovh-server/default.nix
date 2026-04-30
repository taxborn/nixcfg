{
  config,
  lib,
  ...
}:
{
  options.myNixOS.profiles.ovhServer = {
    enable = lib.mkEnableOption "OVH KVM server bundle (serverBase + grub + OVH initrd modules)";
  };

  config = lib.mkIf config.myNixOS.profiles.ovhServer.enable {
    boot.initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "virtio_scsi"
    ];

    myNixOS = {
      profiles = {
        serverBase.enable = true;
        impermanence.extraUserDirs = [ "public" ];
      };
      programs.grub.enable = true; # grub seems to be the only bootloader that works on ovh
      services.backups.client.extraExcludes = [
        "/var/lib/containers"
        "/var/lib/caddy"
      ];
    };
  };
}
