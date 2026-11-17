# hosts

One directory per machine under `hosts/`: `default.nix` imports the host's
role, shared hardware and services, `disko.nix` names its drives, `proxy.nix`
holds its Caddy vhosts, and any other file is hardware only that host has.
See [architecture](./architecture.md) for how they are assembled and
[provisioning](../README.md#provisioning-a-new-host) for adding one.

## at a glance

| host | machine | role | tailnet | boot |
| --- | --- | --- | --- | --- |
| [Argon](#argon) | OVH VPS | `server.nix` | `100.64.2.1` | grub, via `ovh.nix` |
| [Carbon](#carbon) | OVH VPS | `server.nix` | `100.64.2.0` | grub, via `ovh.nix` |
| [Helium](#helium) | home server | `server.nix` | `100.64.1.0` | systemd-boot |
| [Tungsten](#tungsten) | laptop | `workstation` | `100.64.0.1` | lanzaboote |
| [Uranium](#uranium) | desktop | `workstation` | `100.64.0.0` | lanzaboote |

Every host backs up to rsync.net and to Helium. Uranium adds a third repository
on a local SSD. See [backups](./backups.md).

## [Uranium](../hosts/uranium)

My desktop PC, built in August 2023 _(which, in hindsight, was probably a decent
time to build considering pricing over the last few years)_.
[PCPartPicker build](https://pcpartpicker.com/user/taxbornfair/saved/bK7L7P).

i7-13700K CPU, 32 GB of RAM, AMD RX 7900 XT GPU. 2x2TB NVME drives.

LUKS-on-RAID1 across the pair, plus two companion drives outside the mirror: a
512 GB NVMe for the Steam library and a 250 GB SATA SSD holding a third, local
borg repository. Neither is on the mirror, since what lands on them is either
reproducible or already redundant. Keeping them off it also keeps
them out of the root array's snapshot scope.

Steam, gamemode, and the `scx_lavd` scheduler. `/games/steamapps/compatdata` is
a snapper-snapshotted subvolume and is backed up separately from `/home`.

## [Tungsten](../hosts/tungsten)

A Dell [XPS 15 9520](https://www.dell.com/en-us/shop/laptops/xps-15-laptop/spd/xps-15-9520-laptop).
i9-12900HK CPU, 3050 Ti GPU (Intel Xe integrated), 2x1TB NVME drives.

Same LUKS-on-RAID1 layout as Uranium, without the companions, unlocked by a
FIDO2 YubiKey. Hybrid graphics run in PRIME offload with finegrained power
management; a `nvidia-sync` specialisation exists for when that is not enough.

The BIOS attributes on this machine are what the "do not" list in the
[root README](../README.md#do-not) is about. Read it before changing anything
in Setup.

## [Argon](../hosts/argon)

An Intel OVH VPS, `vps-2020-elite-8-16-320` model.
16 GB of RAM, 8 vCPUs, 320 GB of storage.

Carries most of `biscuits.at`. Caddy is `cloudflareOnly`, with the PDS names as
the `directVHosts` exceptions.

### Services hosted

| service | vHost | port | notes |
| --- | --- | --- | --- |
| [Atuin](../modules/nixos/services/atuin.nix) | `atuin.biscuits.at` | 3008 | shell history sync; PostgreSQL; registration closed except for the deploy that creates the account |
| [Glance](../modules/nixos/services/glance.nix) | `www.biscuits.at` | 3000 | dashboard; apex redirects here |
| [ntfy](../modules/nixos/services/ntfy.nix) | `ntfy.biscuits.at` | 3007 | push notifications; backup success messages; deny-all, declarative users |
| [Piper](../modules/nixos/services/piper.nix) | `piper.biscuits.at` | 3005 | teal.fm music tracker |
| [Tangled knot](../modules/nixos/services/tangled/knot.nix) | `knot.biscuits.at` | 3011 | git server, no database; git over SSH on 2222, tailnet-only; proxied record, covered by the zone wildcard |
| [Tranquil PDS](../modules/nixos/services/tranquil-pds.nix) | `pds.biscuits.at` + `*.pds.biscuits.at` | 3003 | ATProto PDS, PostgreSQL |
| [Vaultwarden](../modules/nixos/services/vaultwarden.nix) | `vw.biscuits.at` | 3001 | |
| [Minecraft](../modules/nixos/services/minecraft.nix) (`mnb`) | | 25565 | not behind Caddy; `openFirewall` for friends outside the tailnet; fail2ban jail |

The service modules register `pg_dumpall` for Atuin and Tranquil and SQLite
dumps for Piper and Vaultwarden.

The PDS is why the two `pds` records are the only DNS-only names in the zone.
Cloudflare's universal certificate does not cover a second label,
`subscribeRepos` is a long-lived WebSocket, and the free tier caps request
bodies at 100 MB. See [network](./network.md#directvhosts).

## [Carbon](../hosts/carbon)

An Intel OVH VPS, `vps-2 2026` model.
12 GB of RAM, 6 vCPUs, 100 GB of storage.

### Services hosted

| service | vHost | port | notes |
| --- | --- | --- | --- |
| [braxton.is](../modules/nixos/services/braxton-is.nix) | `braxton.is` + `www.braxton.is` | 3006 | personal site, not under `biscuits.at`; deployed by a CI tarball over a forced-command SSH key; no database |
| [Minecraft](../modules/nixos/services/minecraft.nix) (`mavs-updated`) | | 25565 | not behind Caddy; `openFirewall` for friends outside the tailnet; fail2ban jail |
| [Tangled spindle](../modules/nixos/services/tangled/spindle.nix) | `spindle.biscuits.at` | 3012 | CI as root with rootful Docker and KVM microVMs, one concurrent job, owner only; SQLite dump; needs its own proxied record, since the zone wildcard lands on Argon |

The spindle's SQLite database is the only one on this host, and the backup
client registers a dump of it. Nothing else here is in the backup set beyond
the defaults.

## [Helium](../hosts/helium)

An [Intel NUC8i5BEK](https://www.intel.com/content/dam/support/us/en/documents/mini-pcs/NUC8i3BE_NUC8i5BE_NUC8i7BE_TechProdSpec.pdf)
I use as a home server. 16 GB of RAM, i5-8259U CPU, 2 TB NVME, plus an external
WD My Book at `/mnt/hdd`.

The only host with `tailnetOnly` Caddy. 80/443 are never opened, so every vHost
here has to solve DNS-01. It is also both a backup client and the backup
server, reaching its own repository by local path rather than ssh'ing to itself.

### Services hosted

| service | vHost | port | notes |
| --- | --- | --- | --- |
| [Paperless-ngx](../modules/nixos/services/paperless.nix) | `docs.biscuits.at` | 3004 | PostgreSQL; public A record pointing at a tailnet address |
| [Grafana](./monitoring.md) | `grafana.biscuits.at` | 3009 | with Prometheus, Loki and Alertmanager on loopback; public A record pointing at a tailnet address |
| [borg repositories](./backups.md) | | ssh | `/mnt/hdd/borg/<host>` for every other host |

The external drive is btrfs, mounted `nofail,noatime` with `X-fstrim.notrim`.
It is deliberately not snapshotted, and has no compression: borg archives are
already versioned, encrypted and compressed, so snapshots would only pin the
segments `borg prune` deletes and `compress` would only cost CPU. The
`borg-repo-base` unit carries `RequiresMountsFor`, so backups fail outright when
the drive is absent instead of filling the root filesystem with archives nobody
notices.

The filesystem layout is not declared anywhere in Nix, so a new or reformatted
drive needs this by hand. Afterwards, do not run borg against the repositories
as root, which leaves a repository's `config` unreadable to the forced
`borg serve` (see
[operating](./backups.md#operating)):

```bash
D=/dev/disk/by-id/usb-WD_My_Book_25ED_575835324443304A30443532-0:0
sudo sgdisk --zap-all $D && sudo sgdisk -n1:0:0 -t1:8300 -c1:borg $D
sudo mkfs.btrfs -L borg ${D}-part1
sudo mount -o noatime ${D}-part1 /mnt/hdd
sudo btrfs subvolume create /mnt/hdd/borg
sudo chown -R taxborn:users /mnt/hdd/borg
sudo chmod -R go-rwx /mnt/hdd/borg
```

The `chown` is needed because a fresh btrfs root is `root:root` and
`borg-repo-base` runs as `taxborn`. The `chmod` is the only thing keeping other
local users, such as a compromised service account, from deleting every host's
archives. Nothing else enforces it, so it is lost on a reformat or a restore
that copies modes from somewhere else (rsync from NTFS brought `0777`). After a
restore, rerun both and confirm with `find /mnt/hdd/borg -maxdepth 2 -user
root`, which should print nothing.

## every host

`modules/nixos/common` applies to all five.

- **fstrim** runs monthly rather than weekly. Every btrfs mount uses
  `discard=async` and every LUKS volume allows discards, so the pass mostly
  repeats work. It still covers space the filesystem never allocated.
- **smartd** is on, since scrub and mdadm only report damage that has already
  happened. The OVH module turns it off, because there is no SMART behind
  virtio and smartd fails to start rather than idling.
- **Kernel hardening.** `kexec_load_disabled` (nothing replaces a running
  kernel here, and nixos-anywhere's kexec happens before this config exists).
  `kptr_restrict = 2`, `protected_fifos = 2` and `protected_regular = 2`,
  stricter than NixOS's defaults of 1.
- **nscd** has no start limit. nsncd restarts with the NSS targets several
  times during boot, four times in five seconds on Uranium, which trips the
  default limit and latches it failed for the rest of the boot.
- **The user account** is immutable (`mutableUsers = false`), so its password
  hash comes from agenix. The repository is public and the hash is the sudo
  password everywhere. agenix decrypts before the users activation script. If
  the file were missing, sudo would lock out, so keep a root session open while
  switching anything that touches it.
- **Nix.** `@wheel` is trusted, which is root-equivalent and fine while wheel is
  one person. `keep-going`, 30 log lines, no dirty-tree warning, `keep-outputs`
  and `keep-derivations` so direnv's GC roots survive a collection,
  `accept-flake-config = false`, and free-space thresholds a host can raise.
  The nix-community cache's key can sign any path a host accepts, so removing
  the cache means removing the key.
- **zram swap** with `swappiness = 180` and `page-cluster = 0`. A swap-in is a
  decompression, not a seek, so the kernel should swap well before dropping page
  cache, and readahead would only decompress pages on speculation.
- **btrfs.** Snapper excludes every `snapshotSubvolumes` entry's `.snapshots`
  from backups, and orders `snapper-timeline` after their mounts. Without that
  ordering, its boot catch-up run reached Uranium's compatdata 152 ms before it
  mounted and failed once per boot. Both are derived from the same attribute,
  because the host that adds the next subvolume is the one that would forget.
- **Secret recipients.** `fleet.nix` checks that each age secret a host uses
  exists and names that host and the YubiKey. It reads the rules and public
  keys, never the payload, so it cannot tell whether a file was rekeyed.

## disk layouts

`modules/disko` holds the shared layouts. Each host's `disko.nix` supplies the
`by-id` drive paths.

- `btrfs-opts.nix` holds the mount options every root subvolume shares.
- `btrfs-ovh.nix` (Argon, Carbon) keeps the 2M EF02 partition as well as the
  ESP. Disko adds the disk to `boot.loader.grub.devices` from EF02, so GRUB
  installs for both BIOS and EFI. See [decisions](./decisions.md).
- `btrfs-luks-raid1.nix` (Tungsten, Uranium): an ESP on each disk, mdraid RAID1,
  LUKS enrolled to a FIDO2 YubiKey, btrfs on top.
  - The second ESP is kept in sync by the bootloader. Without it a RAID1 that
    survives losing a disk boots from only one of them.
  - `raidSize` caps the first disk's array partition for mismatched drives.
    Size it against the smaller drive minus its ESP (Tungsten's pair leaves
    927.5 GiB).
  - Optional companions (`games`, `backup`) sit outside the mirror on their own
    LUKS volumes. Their content is reproducible or already redundant. They skip
    compression (game data and borg output are already compressed) and mount
    `nofail`.
  - Companion keyfiles live on the encrypted root, so they unlock from
    crypttab in stage 2, not the initrd. The installer reuses an existing key
    rather than minting a new one, which would lock a re-run out of its data.
  - `/games` keeps `common`, `downloading` and `shadercache` in one subvolume,
    because Steam installs by `rename()` and that fails across subvolumes.
    `/compatdata` (Proton prefixes, so local saves) is split out to be
    snapshotted and backed up. It has no recovery key, since everything on the
    games drive is re-downloadable or backed up.
  - The `backup` volume enrolls a recovery key, printed once at install. Keep it
    with the borg passphrase. Without it, losing the root array takes the local
    repository with it, which is when it is worth the most. `/borg` is never
    snapshotted, since snapshots would pin every segment `borg prune` deletes.
- Helium's single NVMe layout is in `hosts/helium/disko.nix`. Its external
  drive is mounted with `X-fstrim.notrim`. USB spinning disks reject FITRIM,
  which kept `fstrim.service` permanently failed.

## OVH instances

`modules/nixos/ovh.nix` (Argon, Carbon):

- BBR with the `fq` qdisc. Long-haul public paths see drops that are more often
  blips than congestion, and BBR's pacing lives in `fq`. Both modules are loaded
  explicitly so the sysctls name something the kernel knows.
- GRUB installs to the removable media path, because the firmware does not keep
  EFI variables across a rebuild.
- IPv6 is a single /128 whose gateway sits outside it, so the gateway gets an
  on-link route first. NetworkManager's auto-default is disabled for that
  interface only, or it activates a "Wired connection" before the declarative
  profile exists and never switches. Argon carries IPv6 on a second NIC (`ens4`)
  with IPv4 disabled there.

## host notes

- **Uranium.** `aesni_intel` is in the initrd, because dm-crypt picks its
  cipher when stage 1 opens the root and a faster module loaded later does not
  replace it. `iommu=pt` identity-maps devices, since nothing is passed through.
  USB autosuspend is off, because it makes the receiver, keyboard and YubiKey
  re-enumerate. A `cpu-epp` unit sets the HWP performance hint without the
  performance governor. Steam's firewall options stay off (Remote Play over the
  tailnet still works). The Nix free-space thresholds are 5 and 20 GiB for large
  builds. `libvirtd` group membership is root-equivalent, the same trade as
  `wheel`.
- **Uranium libvirt.** swtpm for Windows 11. Guests shut down cleanly with the
  host. `/var/lib/libvirt/images` has a `.nobackup` marker and `+C`
  (no copy-on-write and no checksums, acceptable for throwaway disks only).
  Move a VM you care about out of it.
- **Uranium GPU.** `amdgpu.ppfeaturemask` exposes OverDrive controls for LACT
  or CoreCtrl. It does nothing until a tool writes to them.
- **Tungsten GPU.** `i915` loads in the initrd before nvidia, or Electron apps
  can stall for a minute after boot. The nvidia modules load in stage 2, since
  finegrained power management's udev rules only fire on a `bind` that happens
  after switch-root. Loaded from the initrd, the card never reaches RTD3 and
  draws several watts all session. The PRIME bus IDs are decimal, converted from
  `lspci`'s hex. 32-bit VAAPI is installed so wine and Steam do not fall back to
  software decode.
- **Tungsten power.** boltd authorizes Thunderbolt devices, which are inert
  without it. A critical battery powers off, because hibernation is not set up
  and the default HybridSleep would try to resume from nothing. iwlwifi power
  saving is on. nix-gc and nix-optimise wait for AC power. borgmatic does not,
  because a skipped unit counts as a success and the timer never retries.
