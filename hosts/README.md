# hosts

The main configuration for each host in my homelab, one directory per machine.
Hosts are named after chemical elements, as explained in
[CONTEXT.md](../CONTEXT.md#hosts-are-chemical-elements).

Each host is one directory: `default.nix` for the machine itself, plus
`proxy.nix` where it runs Caddy, and any other file the machine alone needs.
Disk selection and serial numbers live in `disko.nix` beside each host.
See [fleet agreement](../modules/README.md#fleet-agreement) for the checked
rosters and [provisioning](../README.md#provisioning-a-new-host) for the order
in which a new host joins them.

## at a glance

| host | role | profile | tailnet | boot |
| --- | --- | --- | --- | --- |
| [Argon](#argon) | OVH VPS | `profiles.server` | `100.64.2.1` | grub, via `profiles.ovh` |
| [Carbon](#carbon) | OVH VPS | `profiles.server` | `100.64.2.0` | grub, via `profiles.ovh` |
| [Helium](#helium) | home server | `profiles.server` | `100.64.1.0` | systemd-boot |
| [Tungsten](#tungsten) | laptop | `profiles.workstation` | `100.64.0.1` | lanzaboote |
| [Uranium](#uranium) | desktop | `profiles.workstation` | `100.64.0.0` | lanzaboote |

Every host backs up to rsync.net and to Helium. Uranium adds a third repository
on a local SSD. See the [backups README](../modules/nixos/services/backups/README.md).

## [Uranium](./uranium)

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

## [Tungsten](./tungsten)

A Dell [XPS 15 9520](https://www.dell.com/en-us/shop/laptops/xps-15-laptop/spd/xps-15-9520-laptop).
i9-12900HK CPU, 3050 Ti GPU (Intel Xe integrated), 2x1TB NVME drives.

Same LUKS-on-RAID1 layout as Uranium, without the companions, unlocked by a
FIDO2 YubiKey. Hybrid graphics run in PRIME offload with finegrained power
management; a `nvidia-sync` specialisation exists for when that is not enough.

The BIOS attributes on this machine are what the "do not" list in the
[root README](../README.md#do-not) is about. Read it before changing anything
in Setup.

## [Argon](./argon)

An Intel OVH VPS, `vps-2020-elite-8-16-320` model.
16 GB of RAM, 8 vCPUs, 320 GB of storage.

Carries most of `biscuits.at`. Caddy is `cloudflareOnly`, with the PDS names and
Forgejo's tailnet name as the `directVHosts` exceptions.

### Services hosted

| service | vHost | port | notes |
| --- | --- | --- | --- |
| [Atuin](../modules/nixos/services/atuin.nix) | `atuin.biscuits.at` | 3008 | shell history sync; PostgreSQL; registration closed except for the deploy that creates the account |
| [Forgejo](../modules/nixos/services/forgejo/default.nix) | `code.biscuits.at` | 3002 | SQLite; git over SSH on 2222, tailnet-only; also served at `argon.<tailnet>` so LFS uploads skip Cloudflare's 100 MB cap |
| [Glance](../modules/nixos/services/glance.nix) | `www.biscuits.at` | 3000 | dashboard; apex redirects here |
| [ntfy](../modules/nixos/services/ntfy.nix) | `ntfy.biscuits.at` | 3007 | push notifications; backup success messages; deny-all, declarative users |
| [Piper](../modules/nixos/services/piper.nix) | `piper.biscuits.at` | 3005 | teal.fm music tracker |
| [Tangled knot](../modules/nixos/services/tangled/knot.nix) | `knot.biscuits.at` | 3011 | git server, no database; git over SSH on 2223, tailnet-only; proxied record, covered by the zone wildcard |
| [Tranquil PDS](../modules/nixos/services/tranquil-pds.nix) | `pds.biscuits.at` + `*.pds.biscuits.at` | 3003 | ATProto PDS, PostgreSQL |
| [Vaultwarden](../modules/nixos/services/vaultwarden.nix) | `vw.biscuits.at` | 3001 | |

The service modules register `pg_dumpall` for Atuin and Tranquil and SQLite
dumps for Forgejo and Piper when the backup client is enabled.

The PDS is why the two `pds` records are the only DNS-only names in the zone.
Cloudflare's universal certificate does not cover a second label,
`subscribeRepos` is a long-lived WebSocket, and the free tier caps request
bodies at 100 MB. See [`argon/proxy.nix`](./argon/proxy.nix).

## [Carbon](./carbon)

An Intel OVH VPS, `vps-2 2026` model.
12 GB of RAM, 6 vCPUs, 100 GB of storage.

### Services hosted

| service | vHost | port | notes |
| --- | --- | --- | --- |
| [Forgejo runner](../modules/nixos/services/forgejo-runner/README.md) | | | trusted repositories, rootless Podman, one concurrent job |
| [Tangled spindle](../modules/nixos/services/tangled/spindle.nix) | `spindle.biscuits.at` | 3012 | CI as root with rootful Docker and KVM microVMs, one concurrent job, owner only; SQLite dump; needs its own proxied record, since the zone wildcard lands on Argon |

Nothing on this host is in the backup set beyond the defaults. It has no
database.

## [Helium](./helium)

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
| [Grafana](../modules/nixos/services/monitoring/README.md) | `grafana.biscuits.at` | 3009 | with Prometheus, Loki and Alertmanager on loopback; public A record pointing at a tailnet address |
| [AdGuard Home](../modules/nixos/services/adguardhome.nix) | `adguard.biscuits.at` | 3010 | UI only; DNS answers on `100.64.1.0:53`, tailnet only; public A record pointing at a tailnet address |
| [borg repositories](../modules/nixos/services/backups/README.md) | | ssh | `/mnt/hdd/borg/<host>` for every other host |

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
[operating](../modules/nixos/services/backups/README.md#operating)):

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
