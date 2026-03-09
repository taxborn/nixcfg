{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myNixOS.services.sddm = {
    enable = lib.mkEnableOption "sddm display manager";

    autoLogin = lib.mkOption {
      description = "User to autologin.";
      default = null;
      type = lib.types.nullOr lib.types.str;
    };
  };

  config = lib.mkIf config.myNixOS.services.sddm.enable {
    security.pam.services.sddm = {
      enableGnomeKeyring = true;
      fprintAuth = false;
      gnupg.enable = true;
      kwallet.enable = true;
    };

    environment.systemPackages = [ pkgs.adwaita-icon-theme ];

    services.displayManager = {
      autoLogin = lib.mkIf (config.myNixOS.services.sddm.autoLogin != null) {
        enable = true;
        user = config.myNixOS.services.sddm.autoLogin;
      };

      sddm = {
        enable = true;

        settings.Theme = {
          CursorTheme = "Adwaita";
          CursorSize = "24";
        };

        wayland = {
          enable = true;
          compositor = "kwin";
        };
      };
    };
  };
}
