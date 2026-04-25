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

## P2

### [x] apply `mySnippets.nix.settings` at the NixOS level
`snippets/modules/snippets/nix/default.nix:2` defines
`experimental-features = [ "flakes" "nix-command" ]` and `trusted-users`,
but only the home-manager profile applies it. NixOS currently works
because unstable defaults cover flakes - this is fragile. Either apply
the snippet in `modules/nixos/programs/nix/default.nix` or drop the
phantom option.

### [x] clean up tangled-knot firewall and bind address
`modules/nixos/services/tangled-knot/default.nix`:
- `:30` adds `networking.firewall.allowedTCPPorts = [ 22 ]` - openssh
  already opens 22 via `openFirewall = true`. Remove the line.
- `:22` binds knot to `0.0.0.0:9004`. Prefer `127.0.0.1:9004` since
  caddy proxies locally. Defense against a future firewall mistake.

### [x] drop forgejo `log.LEVEL = "Debug"` to `Info`
`modules/nixos/services/forgejo/default.nix:77`. Debug on a public
forge is noisy and can log request internals.

### [x] delete the `homes/profiles/workstation.nix` TODO stub
`homes/profiles/workstation.nix:1-11` is a no-op that re-imports
`./default.nix` with a TODO comment. Either move the GUI block here
(see the P1 item above) or delete the file and have hosts import
`profile-default` directly. Not both.

### [x] minecraft isolation
`modules/nixos/services/minecraft/default.nix:73` runs minecraft
servers as the `taxborn` user. Minecraft/JVM has a noisy RCE history
(log4shell, etc). Move to a dedicated `minecraft` system user per
server instance.

### [x] dedupe `backups.client.repositories` boilerplate
Every host specifies the same `{ rsync, helium }` repositories block
(~10 lines each, ~40 total). Add a helper in
`modules/nixos/services/backups/default.nix` that synthesizes both
repositories from `hostname`, toggled by `enableRsyncRepo` /
`enableHeliumRepo`.

### [x] verify `system.stateVersion = "25.11"` per host
All 5 hosts set `system.stateVersion = "25.11"`. This should be the
version each host was **originally installed at** and must never be
bumped. Confirm per host and document.
Verified via git blame: all 5 hosts had 25.11 at their initial commit.
All are on nixos-unstable tracking toward 25.11. Correct.

### [x] check uranium amd GPU package duplication
`hosts/uranium/default.nix:105-109` sets
`hardware.graphics.extraPackages` explicitly (mesa, vulkan-loader,
vulkan-tools). Check whether `myHardware.amd.gpu` already sets these.
If yes, remove the host-level block. If no, move the packages into the
amd gpu module.

### [x] document carbon `caddy.enableReload = false`
`modules/nixos/services/caddy/default.nix:21` disables graceful
reload, forcing a full restart on every config change. This is almost
certainly a workaround for the tailscale caddy plugin - add an inline
comment explaining why so it does not get flipped back on a cleanup.

### [x] document the PDS age-assurance handlers
`hosts/carbon/proxy.nix:51-70` intercepts Bluesky's moderation
endpoints. Add a comment describing the intent so future-me does not
delete it during a proxy cleanup.

### [x] helium-01 boot.initrd.availableKernelModules
`hosts/helium-01/default.nix:123-130` sets initrd modules at the host
level. These are usually generated into hardware-configuration.nix.
Confirm this is not shadowing anything.
Verified: helium-01 has no hardware-configuration.nix import, and
the disko config sets no initrd modules. The host-level definition
is authoritative and not shadowing anything.

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

---

## done

### [x] 2026-04-09 - scope single-service agenix secrets to their host
Replaced the global `keys` default with per-host `hostKeys` calls in
`secrets/secrets.nix`. New mapping:
- `hash-haus.age` -> argon
- `grafana.age` -> helium-01
- `pds.age`, `forgejo/postgres.age`, `forgejo/signing_key.age`,
  `resend.age` -> carbon
- `forgejo/act-runner.age` -> carbon, argon, helium-01
  (all three run forgejo-runner; see P3 "consolidate forgejo-runners
  off carbon")
- `lastfm.age` -> carbon, uranium, tungsten
- `tailscale/{auth,caddyAuth}.age` stay on every host
- borg per-host secrets already scoped; moved onto the new `hostKeys`
  helper for consistency
Requires `agenix -r` (with yubikey) to re-encrypt the existing ciphertexts
against the new recipient sets, then deploy every host.

### [x] 2026-04-09 - split GUI out of `homes/profiles/default.nix`
Verified already resolved. `default.nix` is the clean shell/dev base,
`workstation.nix` carries the GUI block (hyprland, firefox, etc).
Carbon/argon/helium-01 import `profile-server` which extends
`default.nix`; uranium/tungsten import `profile-workstation`. Confirmed
by building
`.#nixosConfigurations.carbon.config.home-manager.users.taxborn.home.activationPackage`
- closure contains no firefox, hyprland, ghostty,
obs-studio, minecraft, vlc, zed-editor, bitwarden, discord, spotify,
obsidian, nemo, or feh.
