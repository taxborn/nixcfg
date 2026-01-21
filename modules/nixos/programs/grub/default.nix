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
      efiInstallAsRemovable = true;
    };
  };
}
