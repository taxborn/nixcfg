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
        # XDG_VTNR leaks into SSH sessions here, so key off the tty instead.
        if test -z "$WAYLAND_DISPLAY"; and test -z "$SSH_CONNECTION"; and test (tty) = /dev/tty1
            start-hyprland
        end
      '';
    };

    # home-manager's programs.hyprlock only writes config; the PAM service is a
    # NixOS concern. Without it hyprlock falls through to /etc/pam.d/other,
    # which is pam_deny, so no password would ever unlock the screen.
    security.pam.services.hyprlock = { };

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
