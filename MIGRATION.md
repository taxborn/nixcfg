# nixcfg full-fleet reinstall: durable, secure, declarative

## Context

Going to wipe and reimage all five NixOS hosts (argon, carbon,
helium-01, tungsten, uranium) and want the rebuild to close four standing
gaps:

1. **Recovery confidence.** No tested runbook today proves a dead host
   can come back from flake + secrets + borg.
2. **Yubikey lockout risk.** `taxborn_yubikey` is the only root SSH
   recipient on every host (P1 backlog item). Lose the key, lose carbon
   and argon. agenix has the same single-point-of-failure for secret
   decryption.
3. **State drift.** Service data lives in opaque `/var/lib/*` paths,
   container volumes, and `/home`. Nothing today distinguishes
   declarative state from accidental state -- a wipe would silently
   delete things you didn't realize mattered.
4. **Public-host hardening.** carbon and argon are internet-facing.
   SSH config still allows password+keyboard-interactive at the protocol
   layer (just disabled via setting), and forgejo-runners on carbon
   colocate pushed CI with vaultwarden + PDS.

Decisions: full re-architecture, all five hosts, disko + impermanence
fleet-wide, recovery-host promotion, and runner relocation off carbon.
No new hardware -- helium-01 absorbs the recovery role.

Intended outcome: every host can be wiped to bare metal and rebuilt
in under an hour from `nixos-anywhere + flake + secrets + borg`, with a
documented and rehearsed runbook, a real second factor for the secrets
chain, and a clean separation between "this is in nix" and "this is
restored from borg".

---

## Architecture changes

### A. Impermanence (root on btrfs blank-snapshot rollback)

Every host moves to the same pattern: `/` is a btrfs subvolume that gets
rolled back to a `blank` snapshot on every boot. Persistent state lives
on a separate `/persist` subvolume, bind-mounted into the paths that
actually need to survive. Drop in `nix-community/impermanence` as a
flake input and a NixOS module.

**Per-host persisted paths (the only state that survives a reboot):**

| Host       | Persisted paths                                                                                              |
|------------|--------------------------------------------------------------------------------------------------------------|
| all        | `/persist/{etc/ssh, etc/machine-id, var/lib/{nixos,systemd,tailscale,fail2ban}, var/log}`                    |
| all        | `/persist/home/taxborn` (or full `/home` on workstations -- `/home` already on a separate LUKS disk there)   |
| argon      | `+ /var/lib/{caddy,gitea-actions-runner,podman}` (taxborn-public hash-haus assets, runner workspaces)        |
| carbon     | `+ /var/lib/{caddy,forgejo,vaultwarden,pds,podman}, /var/cache/forgejo`                         |
| helium-01  | `+ /var/lib/{caddy,immich,paperless,prometheus,loki,grafana,gitea-actions-runner,borg-snapshots}`  |
| helium-01  | `+ /mnt/hdd/borg-repos` (already external, just keep it -- see disk change below)                            |
| tungsten   | workstation: `/home` and `/persist` are subvols of the new RAID1 btrfs pool (see section F)                  |
| uranium    | workstation: `/home` and `/persist` are subvols of the new RAID1 btrfs pool (see section F)                  |

**Files to add/modify:**
- `flake.nix:4` -- add `impermanence.url = "github:nix-community/impermanence"` input.
- `modules/flake/nixos.nix` -- pass `impermanence.nixosModules.impermanence` into every host.
- `modules/nixos/profiles/impermanence/default.nix` (NEW) -- defines
  `myNixOS.profiles.impermanence.enable`. Sets `environment.persistence."/persist"`
  with the all-host base list, plus a `boot.initrd.postDeviceCommands` block
  that does the btrfs rollback (`btrfs subvolume delete /mnt/root && btrfs subvolume snapshot /mnt/blank /mnt/root`).
- `modules/disko/*` -- each disko config gains a `blank` and `persist`
  subvolume alongside `/root`, `/nix`, `/swap`. luks-btrfs-{tungsten,uranium}
  keep `/home` on the second disk.
- Each `hosts/*/default.nix` -- enables `myNixOS.profiles.impermanence.enable = true`
  and adds the host-specific extra persisted paths via
  `environment.persistence."/persist".directories`.

### B. Service redistribution

| Service              | Before              | After              | Rationale                                    |
|----------------------|---------------------|--------------------|----------------------------------------------|
| forgejo-runner       | carbon, argon, h-01 | argon, helium-01   | carbon stops executing pushed CI (P3)        |
| vaultwarden          | carbon              | carbon             | unchanged; primary credential store          |
| pds                  | carbon              | carbon             | unchanged                                    |
| forgejo (forge)      | carbon              | carbon             | unchanged                                    |
| recovery role        | (none)              | helium-01          | NEW: see section C                           |

**Files to modify:**
- `hosts/carbon/default.nix:53-57` -- delete the `forgejo-runner` block.
- `hosts/carbon/default.nix:39-43` -- drop `/var/lib/gitea-actions-runner` from `extraExcludes`.

### C. Recovery / break-glass on helium-01

Without a second yubikey, the chain has to be: (1) a paper-backed
ed25519 SSH key + age recipient, (2) a passphrase-encrypted offline
copy of the agenix master key on helium-01 `/persist/recovery/`, and
(3) a mirror clone of the `secrets` repo so a wiped host can re-flake
from a Tailscale-local source if the upstream is down.

**Files to add/modify:**
- `secrets` repo (out-of-tree) -- generate a fresh ed25519 keypair on
  an air-gapped machine; store private key as paper QR + USB cold copy;
  add `publicKeys/taxborn_recovery.pub` and re-encrypt every `.age` file
  with the new recipient via `agenix -r`.
- `modules/nixos/profiles/recovery-host/default.nix` (NEW) -- option
  `myNixOS.profiles.recoveryHost.enable`. When enabled:
  - Persists `/persist/recovery/` (mirror clone of secrets repo,
    passphrase-encrypted age key, runbook copy, last-known-good
    nixos-anywhere installer ISO).
  - Adds a systemd timer that `git pull`s the secrets repo every 6h
    into `/persist/recovery/secrets.git` (bare clone, read-only).
  - Adds a systemd service that exposes the recovery dir read-only over
    Tailscale on a hidden caddy vhost (mTLS, restricted to the recovery
    pubkey).
- `hosts/helium-01/default.nix` -- enable `myNixOS.profiles.recoveryHost.enable = true`.
- `docs/recovery-runbook.md` (NEW) -- step-by-step disaster recovery,
  including the yubikey-lost branch.

### D. SSH + auth hardening (fleet-wide)

**File:** `modules/nixos/services/openssh/default.nix:13-17`.
Add to `services.openssh.settings`:
```
KbdInteractiveAuthentication = false;
AuthenticationMethods = "publickey";
PubkeyAuthentication = true;
```
On argon and carbon only, also move SSH off port 22 (e.g. 2222) -- log
hygiene, not security. Tailscale SSH (`--ssh`, already on) keeps the
operator path independent of the public port.

**File:** `modules/nixos/services/fail2ban/default.nix` -- once SSH
moves off 22 on argon/carbon, the sshd jail's `port` needs to follow
(or use `port = "ssh"` with a `services.openssh.ports = [ 2222 ]`
single source of truth).

### E. Backup hygiene + restore tests

**Issues to fix:**
1. `hosts/helium-01/default.nix:39` sets `enableHeliumRepo = true` --
   helium-01 backs up to itself, which is useless. Set false; keep
   `enableRsyncRepo = true`. helium-01's restore path is rsync.net only.
2. `hosts/helium-01/default.nix:123-136` -- the ntfs-3g `/mnt/hdd`
   mount (P1 backlog) gets reformatted to ext4 (or btrfs) during the
   helium-01 reinstall window. Change `fileSystems."/mnt/hdd".fsType`
   accordingly and update disko if you want it declarative.
3. Add `modules/nixos/services/backups/restore-test.nix` (NEW) -- a
   weekly systemd timer that mounts the most recent archive into
   `/var/lib/borg-snapshots/<repo>/<date>/`, runs `borg check` and a
   small `find -type f | wc -l` sanity test, and emits to journald.
   fluent-bit picks it up; grafana alerts on missing weekly success.

### F. Disk layout fixes (per-host, on reinstall)

| Host      | Change                                                                                       |
|-----------|----------------------------------------------------------------------------------------------|
| tungsten  | btrfs RAID1 across both NVMes (LUKS+FIDO2 per disk); ESP /boot=4G on nvme1n1 (SK Hynix)      |
| uranium   | btrfs RAID1 across both Samsung 980 PROs (LUKS+FIDO2 per disk); /boot on Samsung 850 SATA    |
| helium-01 | `/mnt/hdd` -> ext4 (or btrfs); declare in disko (`modules/disko/btrfs-helium-01/default.nix`)|
| all       | Add `blank` and `persist` btrfs subvolumes (impermanence)                                    |
| argon/carbon | No LUKS (per call) -- OVH disks stay plaintext; keep grub bootloader                      |

#### Workstation RAID1 detail

Both workstation disko configs follow the same pattern:

```
disk A (LUKS+FIDO2) -- btrfs member 1 \
                                       > btrfs RAID1 (data=raid1, metadata=raid1)
disk B (LUKS+FIDO2) -- btrfs member 2 /
        |
        +-- subvolumes: /root (rolled back), /nix, /persist, /home, /swap
```

**uranium specifics:**
- ESP /boot (4G) on Samsung 850 EVO 250GB SATA (`ata-Samsung_SSD_850_EVO_250GB_*`).
  Chosen over Patriot M.2 P300 because 850 EVO has a longer reliability
  track record and /boot doesn't need NVMe speed. Patriot stays unused
  for now; reserve for a future local borg cache or scratch.
- Data RAID1 across the two Samsung 980 PRO 2TBs
  (`nvme-Samsung_SSD_980_PRO_2TB_S76ENL0X900787H` +
  `nvme-Samsung_SSD_980_PRO_2TB_S76ENL0X900698K`).
- Effective usable capacity: ~2TB (was 4TB unmirrored). Don't need the
  full space. Survives a single-NVMe failure with no downtime via
  `btrfs replace`.
- Both LUKS containers FIDO2-enrolled to the same yubikey -> single
  tap unlocks both.

**tungsten specifics:**
- ESP /boot (4G) on nvme1n1 (`PC801 NVMe SK hynix 1TB`). Replaces the
  current 512M ESP that's at 85%. Single ESP -- if this drive dies,
  boot from USB rescue, restore ESP from clone, data still intact on
  the mirror.
- Data RAID1 across nvme1n1 (SK Hynix, ~949G remaining after ESP) and
  nvme0n1 (`WDC WDS100T2B0C-00PXH0`, 931.5G).
- Effective usable capacity: ~931GB (capped to smaller member, was
  ~1.85T unmirrored).
- Mismatched drives are actually a RAID1 plus: uncorrelated failure
  modes (different controllers, different firmware lineages).
- Both LUKS containers FIDO2-enrolled to the same yubikey.

**Caveats to know going in:**
- RAID1 doubles write wear (every write goes to both members). On
  workstations this is fine; just don't think of RAID1 as a backup --
  borg still does that job.
- btrfs RAID1 needs `mount -o degraded` to come up read-write with one
  drive missing; set this in `boot.initrd.luks.devices.*` and as
  a `fileSystems."/".options` entry with appropriate caution
  (degraded-mount is intentionally one-shot and re-mirrored on
  replacement).
- /home moves into the same btrfs pool as /, breaking the previous
  "/home on its own LUKS device" property. Encryption is preserved
  (both members are LUKS-wrapped), and the operational benefit of
  separate-device /home was minimal -- the borg-restore unit of
  recovery doesn't change.

### G. Deploy ergonomics

**File:** `justfile` -- add `install` target wrapping `nixos-anywhere`:
```
install host target:
    nix run github:nix-community/nixos-anywhere -- \
        --flake .#{{host}} \
        --target-host {{target}}
```
Keeps `deploy` as the steady-state in-place rebuild; `install` is the
greenfield bootstrap.

---

## Reinstall order (derisk-first)

1. **VM dry-run.** Stand up a throwaway nixos-anywhere install of a
   stub host using the new disko + impermanence pattern. Goal: prove
   the rollback works, secrets decrypt, tailscale joins. Zero
   production risk.
2. **In-place hardening.** Add second recovery key, rotate agenix
   recipients, harden SSH, add restore-test timer, fix
   `enableHeliumRepo` on helium-01. Deploy normally. No reinstalls yet.
3. **Pre-stage cold dumps.** Before any reinstall: postgres dumps
   (forgejo, vaultwarden), sqlite copies (pds), immich +
   paperless data archives, glance config. Push to rsync.net under a
   `pre-reimage-2026-04-XX/` prefix. Verify integrity.
4. **Reinstall argon** (lowest blast radius). Restore container vols
   from helium-01 borg.
5. **Reinstall tungsten** (workstation, validates LUKS+FIDO2 +
   impermanence; uranium stays alive as fallback). Restore /home.
6. **Reinstall uranium**, applying any tungsten lessons.
7. **Reinstall carbon.** Restore forgejo/vaultwarden/PDS state from
   the cold dumps + helium-01 borg.
8. **Reinstall helium-01 LAST.** Source of restore: rsync.net only
   (it's its own backup target, but with `enableHeliumRepo = false`
   that's no longer self-referential). Sequence: nixos-anywhere ->
   reformat /mnt/hdd to ext4 -> restore borg-repos from rsync.net ->
   restore service data (immich, paperless, prometheus
   tsdb, loki chunks, grafana db) -> re-enable other hosts'
   enableHeliumRepo so the helium repo path resumes.

After step 8, every host is running a fresh impermanent install, the
recovery host is online, and the runbook has been exercised end-to-end.

---

## Critical files (modify)

- `flake.nix` -- add impermanence input
- `modules/flake/nixos.nix` -- wire impermanence module
- `modules/disko/btrfs-{argon,carbon,helium-01}/default.nix` -- add blank+persist subvols
- `modules/disko/luks-btrfs-tungsten/default.nix` -- rewrite for btrfs RAID1 across both NVMes, ESP=4G on nvme1n1
- `modules/disko/luks-btrfs-uranium/default.nix` -- rewrite for btrfs RAID1 across both Samsung 980 PROs, ESP=4G on Samsung 850 SATA
- `modules/disko/btrfs-helium-01/default.nix` -- declare /mnt/hdd as ext4
- `modules/nixos/profiles/impermanence/default.nix` -- NEW
- `modules/nixos/profiles/recovery-host/default.nix` -- NEW
- `modules/nixos/services/openssh/default.nix` -- harden settings
- `modules/nixos/services/fail2ban/default.nix` -- follow port change
- `modules/nixos/services/backups/restore-test.nix` -- NEW
- `hosts/argon/default.nix` -- enable impermanence, persisted paths, alt SSH port
- `hosts/carbon/default.nix` -- impermanence, drop runners, alt SSH port
- `hosts/helium-01/default.nix` -- impermanence, recovery host, fix enableHeliumRepo, /mnt/hdd ext4
- `hosts/tungsten/default.nix` -- impermanence, persisted paths
- `hosts/uranium/default.nix` -- impermanence, persisted paths
- `justfile` -- add `install` target
- `docs/recovery-runbook.md` -- NEW
- `docs/backlog.md` -- check off P1 ntfs/emergency-key, P3 SSH harden, P3 runner consolidation

## Reuse (existing, don't reinvent)

- `myNixOS.services.backups.client` (`modules/nixos/services/backups/default.nix:103`)
  -- already supports per-host repo selection and exclusion lists. Just
  add the new `/persist` paths to the default `paths` (replacing
  `/var/lib` with `/persist/var/lib`).
- `myNixOS.services.backups.server` (same file, line 163) -- borg server
  on helium-01 is already authorized-key-scoped per host. No changes
  needed beyond rotating per-host keys after reinstall.
- `mySnippets.mischief-town.networkMap` (snippets flake input) -- IP/port
  source of truth for tailscale IPs, loki/node-exporter ports. Recovery
  host module should pull caddy bind addresses from here.
- `myUsers.taxborn` + `users.users.root.openssh.authorizedKeys.keyFiles`
  (`modules/users/default.nix:23-29`) -- already filters
  `taxborn_*` from secrets/publicKeys. Adding `taxborn_recovery.pub`
  there auto-enrolls it on every host.
- `defaultExtraFormatArgs` + `defaultBtrfsOpts` in
  `modules/disko/luks-btrfs-uranium/default.nix:27-34` -- copy these
  helpers into a shared disko snippet rather than re-deriving in each
  disko config.

## Verification

After each reinstall:
1. `nixos-rebuild dry-build --flake .#<host>` from the host -- proves
   the flake matches the on-disk system.
2. `journalctl -u systemd-cryptsetup@cryptroot.service` (workstations)
   -- confirms FIDO2 unlock fired.
3. `tailscale status` -- host visible to fleet, SSH works via tailscale.
4. `borgmatic --verbosity 1 list` for each repo -- archives present.
5. `systemctl is-active prometheus loki grafana` (helium-01) and check
   the dashboards show data from all five `node-exporter` targets.
6. Run `docs/recovery-runbook.md` against a scratch VM end-to-end once.
   That's the durability proof; without it the rest is theory.

After the full cycle:
- `git status` in nixcfg should be clean (no `sys-*.txt` style
  untracked artifacts).
- `agenix -e` against any secret should require either yubikey OR the
  recovery key (verify by removing the yubikey and trying).
- A simulated helium-01 outage (`tailscale down` on helium-01) should
  not break borgmatic on other hosts -- they fall back to rsync.net.
