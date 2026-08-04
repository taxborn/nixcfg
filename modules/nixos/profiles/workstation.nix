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

    boot.kernelPackages = pkgs.linuxPackages_latest;

    programs = {
      hyprland.enable = true;
      fish.loginShellInit = ''
        if test -z "$WAYLAND_DISPLAY"; and test "$XDG_VTNR" = 1
            start-hyprland
        end
      '';
    };

    environment.sessionVariables.NIXOS_OZONE_WL = "1";

    fonts.packages = with pkgs; [
      noto-fonts
      noto-fonts-color-emoji
      nerd-fonts.jetbrains-mono
    ];

    services = {
      blueman.enable = lib.mkIf config.hardware.bluetooth.enable true;
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
      services.yubikey.enable = true;
    };

    hardware = {
      logitech.wireless = {
        enable = true;
        enableGraphical = true;
      };
      keyboard.qmk.enable = true;
    };
  };
}
