# 04 - secrets

## why agenix

- Keeps encrypted secrets in git next to the code that consumes them.
- No external secret manager to run or pay for.
- Works offline; no network round-trip at activation time.
- Unlocks with the host's SSH key, which NixOS already has.

Tradeoff: rotating a compromised key is a git-history event. For
truly sensitive credentials (financial, legal) I use rbw/bitwarden
instead, because interactive rotation matters more than declarative
management.

## the secrets repo

Secrets live in a separate private flake-input repo
(`git.mischief.town/nix-infra/secrets`) rather than in-tree. This lets
`nixcfg` stay public. The input is `flake = false` so the repo is just
a directory of files; `secrets/secrets.nix` declares which public keys
can decrypt which `.age` file.

## key scoping

Two classes of keys:

- **host keys** - each host's `/etc/ssh/ssh_host_ed25519_key.pub`.
  Named `<hostname>_system` in `secrets.nix`.
- **user keys** - yubikey-resident ssh keys used for administrative
  access and for editing secrets from a workstation.

Rule: a secret should only list the hosts that actually need it. A
`forgejo_smtp.age` granted to every host is a smell. The borg secrets
follow this pattern correctly and should be the template.

## agenix and home-manager

agenix is a NixOS module, not a home-manager one. Secrets needed by
home-manager services (rbw config, etc.) are either:

- read from a root-owned path and group-exposed, or
- fetched interactively by the user (bitwarden, yubikey-gpg, rbw).

I prefer the second path where possible. Fewer root-owned files in
`/run/agenix`, and it forces secrets to be human-present operations.

## emergency access

Losing the primary yubikey locks me out of every host that only lists
it as an admin key. Recovery plan: a second yubikey stored offline,
enrolled on every system key list. This is a recovery posture, not a
runtime security one, and is easy to skip until you need it.
