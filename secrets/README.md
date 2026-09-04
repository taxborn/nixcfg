# agenix secrets

[agenix](https://github.com/ryantm/agenix)-encrypted secrets. `secrets.nix` is
the rule file: it maps each `.age` path to the set of public keys that may
decrypt it. It is read by the `agenix` CLI only — the NixOS modules reference
the `.age` files directly.

## who can read what

Recipients come from [`../keys/`](../keys). Two tiers:

- **`keys`** — every host root key plus `yubikey_age.pub`. Used for secrets any
  host may need (`tailscale/*`).
- **`hostKey <host>`** — that one host's root key plus `yubikey_age.pub`. Used
  for everything service- or host-specific.

The yubikey is a recipient of everything, deliberately: it is the identity that
makes a restore possible from a machine holding nothing else. See tier 0 of the
[backups README](../modules/nixos/services/backups/README.md#testing-restore).

Borg material is generated per host by the rules at the top of `secrets.nix`, so
adding a host to the `hosts` list is all a new host's `borg/<host>/` passphrase
and SSH key need.

`piper.age` is a dotenv file for the teal.fm tracker on Argon. It must contain
the ATProto confidential-client key and ID, your allowed DID, and the Spotify
and Last.fm API credentials:

```dotenv
ATPROTO_CLIENT_SECRET_KEY=
ATPROTO_CLIENT_SECRET_KEY_ID=
ALLOWED_DIDS=did:plc:...
SPOTIFY_CLIENT_ID=
SPOTIFY_CLIENT_SECRET=
LASTFM_API_KEY=
```

Generate the first value with `goat key generate -t P-256`; the key ID must be
persistent and unique (a Unix timestamp is suitable). `ALLOWED_DIDS` is a
space-separated allowlist and must include your DID, otherwise anyone with an
ATProto account could sign in.

`ssh_key.pub` and `signing-key.pub` files sit unencrypted beside their `.age`
counterparts on purpose — public halves are not secret, and Helium's
`server.authorizedKeys` and Forgejo's signing config read them from the repo.

## working with them

All of these must run from this directory. agenix resolves its file argument as
a rule name verbatim, so running from the repo root finds no matching rule.

```bash
cd secrets

agenix -e vaultwarden/mail.age    # create or edit
agenix -d vaultwarden/mail.age    # print to stdout
agenix -r                         # rekey everything after changing recipients
```

`agenix -e` decrypts an existing target before opening it, so to *replace* a
secret wholesale, delete the `.age` file first rather than piping over it.

Decrypting locally needs the yubikey identity passed explicitly —
`age.identityPaths` is system-level and does not apply to the CLI:

```bash
agenix -d borg/argon/passphrase.age -i ~/.config/age/yubikey-identity.txt
```

The justfile wraps that as `just restore-keys`, which checks every host's borg
material at once.

## adding a host

1. Install the host, then collect its `/etc/ssh/ssh_host_ed25519_key.pub` into
   `../keys/root_<host>.pub`.
2. Add `<host>` to the `hosts` list in `secrets.nix`.
3. `agenix -r` to rekey, and rebuild the host.

Until step 1 lands, a host is a recipient of nothing, and activation reports a
failed decrypt for every secret its modules ask for. This is why the workstation
bootstrap in [TODO.md](../TODO.md) is ordered the way it is.

Borg key material has its own provisioning sequence, in the
[backups README](../modules/nixos/services/backups/README.md#provisioning-a-host).
