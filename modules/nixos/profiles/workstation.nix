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
      niri.enable = true;
      noctalia = {
        enable = true;
        recommendedServices.enable = true;
      };
      fish.loginShellInit = ''
        # XDG_VTNR leaks into SSH sessions here, so key off the tty instead.
        # niri-session opens a noninteractive login shell to import the environment.
        # Only the original interactive login should launch the session.
        if status is-interactive; and test -z "$WAYLAND_DISPLAY"; and test -z "$SSH_CONNECTION"; and test (tty) = /dev/tty1
            exec ${lib.getExe' config.programs.niri.package "niri-session"}
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

    myHardware.logitech.mx-master.enable = true;

    myNixOS = {
      base.enable = true;
      profiles = {
        audio.enable = true;
        bluetooth.enable = true;
        btrfs.guiTools = true;
        containers.enable = true;
        graphical-boot.enable = true;
      };
      services.yubikey.enable = true;
    };

    hardware = {
      keyboard.qmk.enable = true;
    };
  };
}
