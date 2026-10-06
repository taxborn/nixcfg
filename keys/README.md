# keys

Public key material, unencrypted on purpose. Nothing secret lives here. These
are the halves meant to be published, and several modules read them straight out
of the repo rather than through agenix.

| file | what it is | read by |
| --- | --- | --- |
| `root_<host>.pub` | that host's `/etc/ssh/ssh_host_ed25519_key.pub` | `secrets/secrets.nix` as an age recipient, and `mySnippets.ssh.knownHosts` for host key pinning |
| `yubikey.pub` | my SSH public key, backed by the YubiKey | `modules/users/taxborn.nix` (`authorizedKeys.keyFiles`); also the key to preauthorize on a host before `nixos-anywhere` |
| `yubikey_age.pub` | the age recipient for the same YubiKey | `secrets/secrets.nix`, as the second recipient of every secret |
| `pgp.asc` | my OpenPGP public key, `F22AFD6CFD66B874` | `modules/home/programs/gpg.nix`, imported into the keyring so the card's key is trusted for git signing |
| `cloudflare-origin-pull.pem` | Cloudflare's origin-pull CA certificate | `modules/nixos/services/caddy.nix`, as the trust pool for the `cloudflare-mtls` snippet |

## the two YubiKey entries are not interchangeable

`yubikey.pub` is an SSH key and `yubikey_age.pub` is an age recipient. Same
piece of hardware, different layers: the first gets a shell, the second decrypts
a secret. Both are recorded here.

`yubikey_age.pub` is a recipient of every secret on purpose. The
[secrets README](../secrets/README.md#who-can-read-what) explains why.

## adding a host

Collect the installed machine's `/etc/ssh/ssh_host_ed25519_key.pub` into
`root_<host>.pub` before adding the host to `secrets/secrets.nix`. Until that
file exists the host is a recipient of nothing, and agenix activation fails on
the first `.age` file it cannot decrypt.

## rotating the origin-pull certificate

The private half lives only in Cloudflare; nothing here needs it. Rotating means
generating a fresh pair, uploading it there, and replacing this file. Adding
another zone means uploading this same certificate to it.

`secrets/borg/<host>/ssh_key.pub` and `secrets/forgejo/signing-key.pub` follow
the same convention one directory over, public halves kept beside their `.age`
counterparts. See the [secrets README](../secrets/README.md) for why.
