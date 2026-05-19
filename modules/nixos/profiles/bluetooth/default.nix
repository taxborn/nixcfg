{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myNixOS.profiles.bluetooth.enable = lib.mkEnableOption "enable bluetooth";

  config = lib.mkIf config.myNixOS.profiles.bluetooth.enable {
    hardware.bluetooth = {
      enable = true;
      powerOnBoot = true;
    };

    services.pulseaudio = {
      package = pkgs.pulseaudioFull;

      extraConfig = ''
        load-module module-bluetooth-discover
        load-module module-bluetooth-policy
        load-module module-switch-on-connect
      '';
    };
  };
}
