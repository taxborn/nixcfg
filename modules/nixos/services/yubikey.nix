{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.yubikey;
in
{
  options.myNixOS.services.yubikey.enable =
    lib.mkEnableOption "smartcard access to the YubiKey, and an `age` that can decrypt with it";

  config = lib.mkIf cfg.enable {
    # `age` execs the plugin as a separate binary, found by name on PATH. This
    # is the copy a person gets at a shell, for `agenix -d -i` against the
    # yubikey identity. The wrapper below is the copy activation gets.
    environment.systemPackages = [ pkgs.age-plugin-yubikey ];

    services = {
      udev.packages = [ pkgs.yubikey-personalization ];

      # age-plugin-yubikey reaches the key through its PIV applet over PC/SC,
      # so with pcscd stopped every yubikey identity fails to decrypt. That
      # includes `just restore-keys`, the tier 0 check that the key on its own
      # can still open a destroyed host's borg material.
      pcscd.enable = true;
    };

    # agenix calls this by absolute store path from the activation script,
    # whose PATH is `/empty` plus a handful of core tools. A bare `age` there
    # meets the `AGE-PLUGIN-YUBIKEY-` identity that workstations name in
    # `age.identityPaths`, finds no plugin to exec, and fails the decrypt.
    age.ageBin = lib.getExe (
      pkgs.writeShellScriptBin "age" ''
        export PATH="${pkgs.age-plugin-yubikey}/bin:$PATH"
        exec ${lib.getExe pkgs.age} "$@"
      ''
    );
  };
}
