{
  pkgs,
  config,
  lib,
  ...
}:
with lib;
let
  cfg = config.extraServices.virtualisation;
in
{
  options.extraServices.virtualisation.enable = mkEnableOption "enable virt-manager virtualisation";

  config = mkIf cfg.enable {
    virtualisation.libvirtd = {
      enable = true;
      qemu.vhostUserPackages = with pkgs; [ virtiofsd ];
    };
    programs.virt-manager.enable = true;

    users.users.taxborn.extraGroups = [ "libvirtd" ];
  };
}
