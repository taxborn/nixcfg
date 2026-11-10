let
  hosts = [
    "argon"
    "carbon"
    "helium"
    "tungsten"
    "uranium"
  ];
  # The YubiKey, deliberately a recipient of every rule below. If a host is
  # gone, it is the only key left that can open its archives.
  extras = [
    "yubikey_age"
  ];

  # Two tiers of recipient. `keys` is every host root plus the YubiKey, for
  # material any host might need; `hostKey` narrows to one host, and is the
  # default for everything else.
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

  # Cloudflare token with DNS edit rights, as `CF_API_TOKEN=...`. Only the hosts
  # whose vHosts import `cloudflare-dns` decrypt it; carbon runs CI as root and
  # has no use for it. Keep this list in step with `usesDnsChallenge` in
  # `modules/nixos/services/caddy.nix`.
  "cloudflare/dns-token.age".publicKeys =
    builtins.map (host: builtins.readFile ../keys/root_${host}.pub) [
      "argon"
      "helium"
    ]
    ++ extraKeys;

  "forgejo/signing-key.age".publicKeys = hostKey "argon";
  "forgejo/mail.age".publicKeys = hostKey "argon";

  "glance.age".publicKeys = hostKey "argon";
  "piper.age".publicKeys = hostKey "argon";
  "vaultwarden.age".publicKeys = hostKey "argon";

  # The ntfy server's users, ACLs and tokens as one environment file. It holds
  # the publisher token as well, so a token rotated in `ntfy/token.age` has to
  # be rotated here too or every host's publish is rejected.
  "ntfy.age".publicKeys = hostKey "argon";

  # The write-only publisher token, on its own so that every backup client can
  # read it without any of them being able to read the server's user database.
  "ntfy/token.age".publicKeys = keys;

  # Grafana's admin password on Helium, declared rather than
  # seeded so a rebuild can reproduce the login.
  "grafana/admin-password.age".publicKeys = hostKey "helium";
  "grafana/secret-key.age".publicKeys = hostKey "helium";

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

  # KNOT_MASTER_KEY, as an environment file. It unseals the knot's signing
  # keys in /var/lib/knot/sealed-keys: lose it and the knot loses control of
  # every repository's identity. The YubiKey recipient is the off-host copy
  # upstream asks for.
  "tangled/knot.age".publicKeys = hostKey "argon";

  # The spindle's P-256 signing key, published in its DID document. Carbon's
  # alone, since Carbon runs the CI jobs and Argon must not be able to read it.
  "tangled/spindle-key.age".publicKeys = hostKey "carbon";

  "users/taxborn-password.age".publicKeys = keys;
}
// borgSecrets
