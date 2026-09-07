{
  config,
  lib,
  self,
  ...
}:
let
  hosts = builtins.attrNames self.nixosConfigurations;
  rules = import "${self}/secrets/secrets.nix";
  ruleNames = builtins.attrNames rules;
  borgHosts =
    suffix:
    map (name: lib.removeSuffix suffix (lib.removePrefix "borg/" name)) (
      builtins.filter (name: lib.hasPrefix "borg/" name && lib.hasSuffix suffix name) ruleNames
    );
  rootKey = host: lib.trim (builtins.readFile "${self}/keys/root_${host}.pub");
  recoveryKey = lib.trim (builtins.readFile "${self}/keys/yubikey_age.pub");
  hostname = config.networking.hostName;
in
{
  # Check the rules and public keys, never the encrypted payload. This catches
  # a service moved to a host that is not a recipient before activation fails.
  config.assertions = [
    {
      assertion = hosts == builtins.attrNames config.mySnippets.tailnet.tailscaleIPs;
      message = "The NixOS host roster and tailnet map must contain the same hosts.";
    }
    {
      assertion = hosts == borgHosts "/passphrase.age" && hosts == borgHosts "/ssh_key.age";
      message = "The NixOS host roster and both sets of per-host borg secret rules must agree.";
    }
    {
      assertion =
        lib.all
          (
            name:
            let
              recipients = map lib.trim rules.${name}.publicKeys;
            in
            builtins.elem recoveryKey recipients
            && lib.all (host: builtins.elem (rootKey host) recipients) hosts
          )
          [
            "tailscale/auth.age"
            "tailscale/caddy.age"
          ];
      message = "Shared tailnet secrets must name every host root key and the recovery YubiKey.";
    }
  ]
  ++ lib.mapAttrsToList (
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
