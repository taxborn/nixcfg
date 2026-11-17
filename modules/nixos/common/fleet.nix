{
  config,
  lib,
  self,
  ...
}:
let
  rules = import "${self}/secrets/secrets.nix";
  rootKey = host: lib.trim (builtins.readFile "${self}/keys/root_${host}.pub");
  recoveryKey = lib.trim (builtins.readFile "${self}/keys/yubikey_age.pub");
  hostname = config.networking.hostName;
in
{
  config.assertions = lib.mapAttrsToList (
    name: secret:
    let
      path = toString secret.file;
      rule = builtins.unsafeDiscardStringContext (lib.removePrefix "${self}/secrets/" path);
      recipients = map lib.trim (rules.${rule}.publicKeys or [ ]);
    in
    {
      assertion =
        builtins.pathExists secret.file
        && builtins.elem (rootKey hostname) recipients
        && builtins.elem recoveryKey recipients;
      message = "${hostname}: age secret ${name} must exist and its rule must include this host and the recovery YubiKey.";
    }
  ) config.age.secrets;
}
