{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.myNixOS.services.yubikey.enable = lib.mkEnableOption "yubikey config";

  config = lib.mkIf config.myNixOS.services.yubikey.enable {
    services = {
      udev.packages = [ pkgs.yubikey-personalization ];
      pcscd.enable = true;
    };

    age.ageBin = lib.getExe (pkgs.writeShellScriptBin "age" ''
      export PATH="${pkgs.age-plugin-yubikey}/bin:$PATH"
      exec ${lib.getExe pkgs.age} "$@"
    '');
  };
}
