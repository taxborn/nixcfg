# hosts

The main configuration for each host in my homelab, one directory per machine.
Hosts are named after chemical elements. The name carries no meaning beyond
identity; role is a property of the config.

Each host is one directory: `default.nix` for the machine itself, plus
`proxy.nix` where it runs Caddy, and any other file the machine alone needs.
The roster lives in [`modules/flake/hosts.nix`](../modules/flake/hosts.nix),
[`secrets/secrets.nix`](../secrets/secrets.nix), and
`mySnippets.tailnet.tailscaleIPs`. A host has to be in all three to be built,
to hold secrets, and to be backed up.

<!-- TODO: Images of each system, if applicable. -->

## at a glance

| host | role | profile | tailnet | boot |
| --- | --- | --- | --- | --- |
| [Argon](#argon) | OVH VPS | `profiles.server` | `100.64.2.1` | grub, via `profiles.ovh` |
| [Carbon](#carbon) | OVH VPS | `profiles.server` | `100.64.2.0` | grub, via `profiles.ovh` |
| [Helium](#helium) | home server | `profiles.server` | `100.64.1.0` | systemd-boot |
| [Tungsten](#tungsten) | laptop | `profiles.workstation` | `100.64.0.1` | lanzaboote |
| [Uranium](#uranium) | desktop | `profiles.workstation` | `100.64.0.0` | lanzaboote |

Every host backs up to two borg repositories, and Helium is the second of those
two. See the [backups README](../modules/nixos/services/backups/README.md).

## [Uranium](./uranium)

My desktop PC, built in August 2023 _(which, in hindsight, was probably a decent
time to build considering pricing over the last few years)_.
[PCPartPicker build](https://pcpartpicker.com/user/taxbornfair/saved/bK7L7P).

i7-13700K CPU, 32 GB of RAM, AMD RX 7900 XT GPU. 2x2TB NVME drives.

LUKS-on-RAID1 across the pair, plus two companion drives outside the mirror: a
512 GB NVMe for the Steam library and a 250 GB SATA SSD holding a third, local
borg repository. Neither earns a place on the mirror, since what lands on them
is either reproducible or already redundant. Keeping them off it also keeps
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

Carries most of `biscuits.at`. Caddy is `cloudflareOnly`, with the PDS names as
the one `directVHosts` exception.

### Services hosted

| service | vHost | port | notes |
| --- | --- | --- | --- |
| [Forgejo](../modules/nixos/services/forgejo/default.nix) | `code.biscuits.at` | 3002 | SQLite; git over SSH on 2222, tailnet-only |
| [Glance](../modules/nixos/services/glance.nix) | `www.biscuits.at` | 3000 | dashboard; apex redirects here |
| [Piper](../modules/nixos/services/piper.nix) | `piper.biscuits.at` | 3005 | teal.fm music tracker |
| [Tranquil PDS](../modules/nixos/services/tranquil-pds.nix) | `pds.biscuits.at` + `*.pds.biscuits.at` | 3003 | ATProto PDS, PostgreSQL |
| [Vaultwarden](../modules/nixos/services/vaultwarden.nix) | `vw.biscuits.at` | 3001 | |

Backups take both a `pg_dumpall` (Tranquil) and a SQLite dump (Piper).

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
| [braxton.is](../modules/nixos/services/braxton-is.nix) | `braxton.is` | 3006 | Astro SSR under `DynamicUser` |

Deploying the site means moving a flake input. `just deploy-site` bumps the
`braxton-is` revision in `flake.lock` and rebuilds, so a rollback is a
generation rollback. Nothing on this host is in the backup set beyond the
defaults. There is no database, and the state directory holds only expendable
sessions.

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
| [borg repositories](../modules/nixos/services/backups/README.md) | | ssh | `/mnt/hdd/borg/<host>` for every other host |

The external drive is NTFS, mounted `nofail` with `X-fstrim.notrim`. The
`borg-repo-base` unit carries `RequiresMountsFor`, so backups fail outright when
the drive is absent instead of filling the root filesystem with archives nobody
notices.
