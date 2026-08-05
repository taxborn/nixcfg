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

  # Forgejo Actions runner secrets. Each is a 40-character hexadecimal string
  # that serves as both the runner's identity and its password — Forgejo derives
  # the runner's UUID from the first 16 characters, so there is no second value
  # to distribute. Carbon needs it to register the runner; the runner's own host
  # needs it to authenticate. Nobody else does.
  runnerHosts = [
    "argon"
    "helium"
  ];

  runnerSecrets = builtins.listToAttrs (
    builtins.map (host: {
      name = "forgejo/runner-${host}.age";
      value.publicKeys = hostKey "carbon" ++ [ (builtins.readFile ../keys/root_${host}.pub) ];
    }) runnerHosts
  );

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

  # Forgejo's SMTP password and its commit-signing key. There is deliberately no
  # database secret: Forgejo is on SQLite, so the database is a file guarded by
  # filesystem permissions and nothing is listening to authenticate against.
  "forgejo/mail.age".publicKeys = hostKey "carbon";
  "forgejo/signing-key.age".publicKeys = hostKey "carbon";

  # Paperless's initial superuser password. Helium only — no other host runs it,
  # and the documents it guards are the reason that service is tailnet-bound.
  "paperless/admin-password.age".publicKeys = hostKey "helium";
}
// runnerSecrets
// borgSecrets
