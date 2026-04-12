# 06 - backups

## topology

Every host runs `myNixOS.services.backups.client` which backs up to
**two repositories**:

1. **rsync.net** - offsite, paid, cold storage. Survives house fire,
   ISP loss, hardware failure, and my own mistakes.
2. **helium-01** - local borg server on the LAN. Fast restores, cheap,
   but shares a failure domain with the house.

Two independent targets is the minimum for a backup system I trust.
One target is "I will lose data eventually"; two targets against
different failure modes means I have to be unlucky twice.

## helium-01 as the LAN borg server

helium-01 exposes a restricted SSH user per client. Each client's
public key in `authorized_keys` is prefixed with
`command="borg serve --restrict-to-repository /mnt/hdd/borg-repos/<host>"`,
so a compromised client can only touch its own repo, not the others.
This is the correct pattern and the reason `authorized_keys` is built
programmatically in the backups module.

`/mnt/hdd/borg-repos` is in every client's `extraExcludes` so
helium-01 does not back itself up recursively.

## what gets backed up

The defaults exclude the obvious: `.cache`, `target`, `node_modules`,
`.venv`, nix store paths, etc. Per-host `extraExcludes` add whatever
else is noise. The philosophy: back up irreplaceable data (documents,
photos, configs, databases), not things that can be rebuilt from a
flake and an internet connection.

Per-service databases (immich, paperless, forgejo, vaultwarden) get
explicit pre-backup hooks to produce consistent dumps. A live SQLite
file is not a consistent backup.

## restore posture

A backup I have never restored from is not a backup. The intended
cadence is a quarterly test restore of at least one repo, to a scratch
directory, end-to-end. This is not automated yet; it should be.

## known risk: filesystem under the LAN repo

The borg repos on helium-01 live on a single external drive. The
filesystem choice matters: borg relies on proper xattrs, sparse files,
and hardlinks. ntfs-3g is known to be unreliable for this. The drive
should be ext4 or btrfs. If it is currently ntfs, that is a bug, not
a design decision - see issue backlog.

## why borg and not restic

Both work. Borg was picked first, the tooling is familiar, dedup
ratios are good for my workload, and rsync.net has native borg
support. No compelling reason to migrate.
