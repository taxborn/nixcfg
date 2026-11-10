# agenix secrets

[agenix](https://github.com/ryantm/agenix)-encrypted secrets. `secrets.nix` is
the rule file, mapping each `.age` path to the set of public keys that may
decrypt it. agenix uses it to encrypt and rekey files. NixOS references the
`.age` files directly and [fleet assertions](../modules/README.md#fleet-agreement)
check their recipient rules before activation.

## inventory

| secret | recipients | what it holds |
| --- | --- | --- |
| `tailscale/auth.age` | all hosts | tailnet auth key |
| `cloudflare/dns-token.age` | argon, helium | `CF_API_TOKEN=...` for Caddy's DNS-01 |
| `borg/<host>/passphrase.age` | that host | borg repokey passphrase |
| `borg/<host>/ssh_key.age` | that host | borg client SSH key |
| `forgejo/mail.age` | argon | Fastmail SMTP password |
| `forgejo/signing-key.age` | argon | SSH key Forgejo signs commits with |
| `glance.age` | argon | dashboard secret key and user password |
| `piper.age` | argon | ATProto client key, allowed DIDs, Spotify + Last.fm creds |
| `tranquil-pds.age` | argon | `JWT_SECRET`, `DPOP_SECRET`, `MASTER_KEY`, SMTP login |
| `vaultwarden.age` | argon | environment file |
| `ntfy.age` | argon | ntfy users, ACLs and tokens as an environment file |
| `ntfy/token.age` | all hosts | write-only ntfy publisher token, read by every backup client |
| `paperless.age` | helium | admin password and SMTP password |
| `grafana/admin-password.age` | helium | Grafana admin password |
| `grafana/secret-key.age` | helium | Grafana `secret_key`, which encrypts its stored data source credentials |
| `tangled/knot.age` | argon | `KNOT_MASTER_KEY`, unseals the knot's signing keys |
| `tangled/spindle-key.age` | carbon | the spindle's P-256 signing key |

`MASTER_KEY` in `tranquil-pds.age` is the one to be most careful with. Every PDS
account's signing key is encrypted under it, so losing a copy loses the instance
and leaking a copy leaks every identity on it.

Everything above is an environment file or a raw credential a service reads at
runtime. None of it is rendered into `settings`, which would land the value in a
world-readable file in the nix store.

## who can read what

Recipients come from [`../keys/`](../keys). Two tiers:

- `keys` covers every host root key plus `yubikey_age.pub`. Used for secrets any
  host may need (`tailscale/*`).
- `hostKey <host>` covers that one host's root key plus `yubikey_age.pub`. Used
  for everything service- or host-specific.

The yubikey appears in both tiers on purpose. If a host is gone, that key is
the only thing left that can open its archives, which is what tier 0 of the
[backups README](../modules/nixos/services/backups/README.md#testing-restore)
checks.

The rules at the top of `secrets.nix` derive borg material per host, so adding a
name to the `hosts` list is the only step a new host's `borg/<host>/` passphrase
and SSH key need.

`piper.age` is a dotenv file for the teal.fm tracker on Argon. It must contain
the ATProto confidential-client key and ID, your allowed DID, and the Spotify
API credentials. Last.fm is disabled (`ENABLE_LASTFM = false` in `piper.nix`):

```dotenv
ATPROTO_CLIENT_SECRET_KEY=
ATPROTO_CLIENT_SECRET_KEY_ID=
ALLOWED_DIDS=did:plc:...
SPOTIFY_CLIENT_ID=
SPOTIFY_CLIENT_SECRET=
```

Generate the first value with `goat key generate -t P-256`. The key ID must be
persistent and unique; a Unix timestamp works. `ALLOWED_DIDS` is a
space-separated allowlist and must include your DID, otherwise anyone with an
ATProto account could sign in.

`ntfy.age` and `ntfy/token.age` share one token. The server provisions users
from `ntfy.age`, and every backup client sends the same token from
`ntfy/token.age`. Generate it with `nix run nixpkgs#ntfy-sh -- token generate`
and create hashes with `nix run nixpkgs#ntfy-sh -- user hash`. Use single
quotes, because bcrypt hashes contain `$`:

```dotenv
NTFY_AUTH_USERS='taxborn:<bcrypt hash>:admin,backups:<bcrypt hash>:user'
NTFY_AUTH_ACCESS='backups:backups:write-only,backups:alerts:write-only'
NTFY_AUTH_TOKENS='backups:tk_<29 chars>:borgmatic'
```

`ntfy/token.age` holds only the `tk_...` string. The `backups` user is
write-only on the `backups` and `alerts` topics, so a leaked token can send fake
success messages or fake alerts and read nothing. The `alerts` grant is what
lets Helium's Alertmanager bridge publish; without it every alert is rejected
with a 403. `taxborn` is the login for the web app and phone.
Rotating the token means editing both files, then rebuilding Argon before the
other hosts, or their next run is rejected.

`ssh_key.pub` and `signing-key.pub` sit unencrypted beside their `.age`
counterparts on purpose. Public halves are not secret, and Helium's
`server.authorizedKeys` and Forgejo's signing config read them from the repo.

## working with them

All of these must run from this directory. agenix resolves its file argument as
a rule name verbatim, so running from the repo root finds no matching rule.

```bash
cd secrets

agenix -e forgejo/mail.age        # create or edit
agenix -d forgejo/mail.age        # print to stdout
agenix -r                         # rekey everything after changing recipients
```

`agenix -e` decrypts an existing target before opening it, so to *replace* a
secret wholesale, delete the `.age` file first rather than piping over it.

Decrypting locally needs the yubikey identity passed explicitly, because
`age.identityPaths` is system-level and does not apply to the CLI:

```bash
agenix -d borg/argon/passphrase.age -i ~/.config/age/yubikey-identity.txt
```

The justfile wraps that as `just restore-keys`, which checks every host's borg
material at once.

## adding a host

Follow the [provisioning sequence](../README.md#provisioning-a-new-host) for
installation, root-key collection, roster registration and rekeying. The root
key must exist before adding a recipient, and the encrypted files must be
rekeyed before the host rebuilds. Changing a rule alone does not change who
can decrypt an existing file.

Borg key material has its own provisioning sequence, in the
[backups README](../modules/nixos/services/backups/README.md#provisioning-a-host).
