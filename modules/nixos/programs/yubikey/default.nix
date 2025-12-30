{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.myNixOS.programs.yubikey.enable = lib.mkEnableOption "yubikey config";

  config = lib.mkIf config.myNixOS.programs.yubikey.enable {
    # TODO: move to yubikey module
    services.udev = {
      packages = [ pkgs.yubikey-personalization ];
    };

    services.pcscd.enable = true;
  };
}
