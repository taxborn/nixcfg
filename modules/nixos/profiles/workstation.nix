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
      solaar.enable = true;
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

      # The MX Master 3S thumb button emits no BTN_* event of its own -- it is a
      # HID++ control that Logi Options+ would interpret -- so there is nothing
      # for Hyprland to bind until logid claims it and synthesises keys through
      # uinput. Those combos are bound in the hyprland keybinds. Solaar's daemon
      # must stay off; it drives HID++ on the same device and the two conflict.
      logiops = {
        enable = true;
        config.devices = [
          {
            name = "MX Master 3S"; # must match the HID++ name solaar reports
            buttons = [
              {
                cid = 195; # 0xc3, the gesture button; nix has no hex literals
                action = {
                  type = "Gestures";
                  gestures = [
                    {
                      direction = "Left";
                      mode = "OnRelease";
                      action = {
                        type = "Keypress";
                        keys = [
                          "KEY_LEFTMETA"
                          "KEY_LEFTBRACE"
                        ];
                      };
                    }
                    {
                      direction = "Right";
                      mode = "OnRelease";
                      action = {
                        type = "Keypress";
                        keys = [
                          "KEY_LEFTMETA"
                          "KEY_RIGHTBRACE"
                        ];
                      };
                    }
                    {
                      # Pressed without moving; SUPER + R is already the wofi bind.
                      direction = "None";
                      mode = "OnRelease";
                      action = {
                        type = "Keypress";
                        keys = [
                          "KEY_LEFTMETA"
                          "KEY_R"
                        ];
                      };
                    }
                  ];
                };
              }
            ];
          }
        ];
      };
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
      logitech.wireless.enable = true;
      keyboard.qmk.enable = true;
    };
  };
}
