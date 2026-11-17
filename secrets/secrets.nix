let
  hosts = builtins.attrNames (import ../homelab.nix).hosts;
  # The only key left that can open a lost host's archives.
  extras = [
    "yubikey_age"
  ];

  systemKeys = builtins.map (host: builtins.readFile ../keys/root_${host}.pub) hosts;
  extraKeys = builtins.map (key: builtins.readFile ../keys/${key}.pub) extras;
  keys = systemKeys ++ extraKeys;

  hostKey = host: [ (builtins.readFile ../keys/root_${host}.pub) ] ++ extraKeys;

  borgSecrets = builtins.listToAttrs (
    builtins.concatMap (host: [
      {
        name = "borg/${host}/passphrase.age";
        value.publicKeys = hostKey host;
      }
      {
        name = "borg/${host}/ssh_key.age";
        value.publicKeys = hostKey host;
      }
    ]) hosts
  );
in
{
  "tailscale/auth.age".publicKeys = keys;

  # Keep in step with the vHosts that import cloudflare-dns.
  "cloudflare/dns-token.age".publicKeys =
    builtins.map (host: builtins.readFile ../keys/root_${host}.pub) [
      "argon"
      "helium"
    ]
    ++ extraKeys;

  "glance.age".publicKeys = hostKey "argon";
  "piper.age".publicKeys = hostKey "argon";
  "vaultwarden.age".publicKeys = hostKey "argon";

  # Holds the publisher token too. Rotate both together.
  "ntfy.age".publicKeys = hostKey "argon";

  "ntfy/token.age".publicKeys = keys;

  "grafana/admin-password.age".publicKeys = hostKey "helium";
  "grafana/secret-key.age".publicKeys = hostKey "helium";

  "paperless.age".publicKeys = hostKey "helium";

  # MASTER_KEY: lose it and the instance is gone.
  "tranquil-pds.age".publicKeys = hostKey "argon";

  "tangled/knot.age".publicKeys = hostKey "argon";

  "tangled/spindle-key.age".publicKeys = hostKey "carbon";

  "users/taxborn-password.age".publicKeys = keys;
}
// borgSecrets
