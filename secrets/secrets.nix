let
  hosts = [
    "argon"
    "carbon"
    "helium"
    "tungsten"
    "uranium"
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

  "forgejo/signing-key.age".publicKeys = hostKey "argon";
  "forgejo/mail.age".publicKeys = hostKey "argon";

  "glance.age".publicKeys = hostKey "argon";
  "vaultwarden.age".publicKeys = hostKey "argon";

  # Helium's, not Argon's — Paperless is the one service off the OVH box.
  # PAPERLESS_ADMIN_PASSWORD and PAPERLESS_EMAIL_HOST_PASSWORD, as one
  # environment file. The admin password is what creates the superuser on first
  # start, so an empty file here is an instance with no way in.
  "paperless.age".publicKeys = hostKey "helium";

  # The PDS's three cryptographic secrets and its Fastmail SMTP login, as one
  # environment file. `MASTER_KEY` is the load-bearing one: every account's
  # signing key is encrypted under it, so a lost copy is a lost instance and a
  # leaked copy is every identity on it.
  "tranquil-pds.age".publicKeys = hostKey "argon";
}
// borgSecrets
