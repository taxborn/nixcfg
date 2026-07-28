let
  hosts = [
    "argon"
    "carbon"
    "helium"
  ];
  extras = [
    "yubikey_age"
  ];

  systemKeys = builtins.map (host: builtins.readFile ../keys/root_${host}.pub) hosts;
  extraKeys = builtins.map (key: builtins.readFile ../keys/${key}.pub) extras;
  keys = systemKeys ++ extraKeys;

  hostKey = host: [ (builtins.readFile ../keys/root_${host}.pub) ] ++ extraKeys;

  # Borg material is per-host: only the host that owns a repository (and I) can
  # read its passphrase and SSH key.
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
  "tailscale/caddy.age".publicKeys = keys;
  "vaultwarden/mail.age".publicKeys = hostKey "carbon";

  # Forgejo's SMTP password and its commit-signing key. There is deliberately
  # no database secret: Forgejo reaches PostgreSQL over the unix socket and
  # authenticates by peer.
  "forgejo/mail.age".publicKeys = hostKey "carbon";
  "forgejo/signing-key.age".publicKeys = hostKey "carbon";
}
// borgSecrets
