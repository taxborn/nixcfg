{
  config,
  lib,
  ...
}:
{
  options.myNixOS.programs.grub.enable = lib.mkEnableOption "boot with grub";

  config = lib.mkIf config.myNixOS.programs.grub.enable {
    boot.loader.grub = {
      enable = true;
      efiSupport = true;

      # The OVH instances are the only hosts here booting GRUB, and their
      # firmware does not keep EFI variables across a rebuild. Installing to
      # the removable media path leaves the loader somewhere the firmware can
      # find without a boot entry pointing at it.
      efiInstallAsRemovable = true;
    };
  };
}
