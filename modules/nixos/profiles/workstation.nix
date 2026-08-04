{
  config,
  lib,
  self,
  pkgs,
  ...
}:
{
  options.myNixOS.profiles.workstation.enable = lib.mkEnableOption "workstation configuration";

  config = lib.mkIf config.myNixOS.profiles.workstation.enable {
    home-manager.users.taxborn.imports = [ self.homeModules.profile-workstation ];

    age.identityPaths = [
      "/etc/ssh/ssh_host_ed25519_key"
      "/home/taxborn/.config/age/yubikey-identity.txt"
    ];

    programs.hyprland.enable = true;
    programs.fish.loginShellInit = ''
      if test -z "$WAYLAND_DISPLAY"; and test "$XDG_VTNR" = 1
          start-hyprland
      end
    '';

    boot.kernelPackages = pkgs.linuxPackages_latest;

    services = {
      blueman.enable = lib.mkIf config.hardware.bluetooth.enable true;

      # Firmware updates over LVFS. This is not a nicety on the laptop: custom
      # Secure Boot keys rule out the vendor's own updater, so UEFI capsules
      # through fwupd are the only route to a current BIOS.
      fwupd.enable = true;

      gnome.gnome-keyring.enable = true;
      gvfs.enable = true; # Mount, trash, etc.
      libinput.enable = true;
    };

    myNixOS = {
      base.enable = true;
      profiles = {
        audio.enable = true;
        bluetooth.enable = true;
        btrfs.guiTools = true;
        graphical-boot.enable = true;
      };
      services = {
        yubikey.enable = true;
      };
    };
  };
}
