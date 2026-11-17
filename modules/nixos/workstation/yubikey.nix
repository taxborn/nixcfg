{
  pkgs,
  lib,
  ...
}:
{
  environment.systemPackages = [ pkgs.age-plugin-yubikey ];

  services = {
    udev.packages = [ pkgs.yubikey-personalization ];

    # Without pcscd no YubiKey identity can decrypt.
    pcscd.enable = true;
  };

  # Activation's PATH is nearly empty, so age needs the plugin wrapped in.
  age.ageBin = lib.getExe (
    pkgs.writeShellScriptBin "age" ''
      export PATH="${pkgs.age-plugin-yubikey}/bin:$PATH"
      exec ${lib.getExe pkgs.age} "$@"
    ''
  );
}
