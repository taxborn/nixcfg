# Hosts

This folder houses the main configuration for each host on for my homelab.

Every host runs the [monitoring client](../modules/nixos/services/monitoring) —
node_exporter, smartctl_exporter where there are real disks, and Alloy shipping
the journal to Loki on Argon. It comes from `base.nix` rather than being opted
into per host, so it is not repeated in the service lists below.

<!-- TODO: Images of each system, if applicable. -->

## [Uranium](./uranium)

My desktop PC I built in August 2023 _(which, in hindsight was probably a decent
time to build considering pricing over the last few years)_. [PCPartPicker build](https://pcpartpicker.com/user/taxbornfair/saved/bK7L7P).

i7-13700K CPU, 32 GB of RAM, AMD RX 7900 XT GPU. 2x2TB NVME drives.

## [Tungsten](./tungsten)

A Dell [XPS 15 9520](https://www.dell.com/en-us/shop/laptops/xps-15-laptop/spd/xps-15-9520-laptop).
i9-12900HK CPU, 3050 Ti GPU (Intel Xe integrated), 2x1TB NVME drives.

## [Argon](./argon)

An Intel OVH VPS, `vps-2020-elite-8-16-320` model.
16 GB of RAM, 8 vCPUs, 320 GB of storage.

### Services hosted

- The [monitoring server](../modules/nixos/services/monitoring): Prometheus,
  Loki, Alertmanager and Grafana, the last at `grafana.<tailnet>` on a Tailscale
  node of Caddy's own. Scrapes and receives logs from every host on the tailnet;
  alerts go to ntfy.
- A forgejo-runner for the forge on Carbon.
- Borg backup client (rsync.net + Helium), excluding the metrics and log stores
  and dumping Grafana's SQLite database.

## [Carbon](./carbon)

An Intel OVH VPS, `vps-2 2026` model.
12 GB of RAM, 6 vCPUs, 100 GB of storage.

### Services hosted

- Main Caddy proxy for all services, plus the fail2ban jail reading its logs.
- [Vaultwarden](../modules/nixos/services/vaultwarden.nix), at `vw.mischief.town`.
- [Forgejo](../modules/nixos/services/forgejo), at `git.mischief.town`, with git
  over SSH on port 2222, tailnet-only. This repository's `origin`.
- Borg backup client (rsync.net + Helium), including a SQLite dump of Forgejo's
  database.

## :balloon: [Helium](./helium)

An [Intel NUC8i5BEK](https://www.intel.com/content/dam/support/us/en/documents/mini-pcs/NUC8i3BE_NUC8i5BE_NUC8i7BE_TechProdSpec.pdf)
I use as a home server. 16 GB of RAM, i5-8259U CPU, 2 TB NVME, plus an external
WD My Book at `/mnt/hdd`.

### Services hosted

- [Borg repository server](../modules/nixos/services/backups), holding the
  second copy of every host's archives on the external drive. Served over real
  sshd on port 2222 with a per-client forced `borg serve --restrict-to-path`.
- Borg backup client for itself (rsync.net + its own local repository).
- Earmarked for Immich and Paperless; see [TODO.md](../TODO.md).

This is the one host with Tailscale SSH turned off — the forced command above is
a security boundary here, and Tailscale SSH would bypass it on port 22. Reaching
Helium needs a real SSH key.
