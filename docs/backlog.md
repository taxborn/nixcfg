# backlog

Open code-level issues identified during the 2026-04-09 infrastructure
review. This is a tracking list, not a design doc. Check items off as
they land; remove items once they are resolved **and** verified.

Severity scale:
- **P1** - correctness bug, security risk, or data-loss exposure
- **P2** - cleanup, dedup, or minor hardening
- **P3** - nice-to-have, speculative refactor

---

### [ ] move helium-01 borg drive off ntfs-3g
`hosts/helium-01/default.nix:132-145` mounts `/mnt/hdd` as `ntfs-3g`.
This is the backup target for every other host. ntfs-3g is known to be
unreliable for sparse files, xattrs, and hardlinks that borg relies on.
Reformat to ext4 or btrfs. Until then, run a scheduled end-to-end
restore test.

### [ ] enroll emergency SSH key on carbon and argon
`secrets/secrets.nix:10-11` lists only `taxborn_yubikey` as a user key.
Losing the yubikey = locked out of carbon and argon. Enroll a second
offline-stored key (second yubikey or a paper-backed ed25519) on both
hosts.

---


## P3

### [ ] introduce an `ovh-server` profile
Carbon and argon share ~30 lines each of near-identical boilerplate
(grub, tailscale, caddy, fail2ban caddy jail, node-exporter, fluent-bit,
backups.client, `myHardware.profiles.ovh`). Factor into
`modules/nixos/profiles/ovh-server/`.

### [ ] consolidate forgejo-runners off carbon
See `docs/design/07-security-posture.md`. Carbon hosts vaultwarden and
the PDS; it should not also run pushed CI code. Move runners to argon
and helium-01 only.

### [ ] harden SSH baseline
`modules/nixos/services/openssh/default.nix:13-17` disables password,
X11, and root login. Consider also setting
`KbdInteractiveAuthentication = false` and
`AuthenticationMethods = publickey`. Moving SSH to a non-standard port
on OVH boxes would cut scanner log noise (not a security win, a log
hygiene one).

### [ ] evaluate ragenix
`flake.nix:7` has a TODO on the agenix input. If ragenix offers
anything meaningful (rage backend, faster decryption), migrate.
Otherwise drop the TODO.

### [ ] audit snippets repo for public-safety
`snippets/modules/snippets/mischief-town/default.nix:8-14` contains
tailscale CGNAT IPs. Not externally routable, but the snippets repo
should be reviewed for anything that should not be public. If in
doubt, make the repo private and keep `secrets` as-is.
