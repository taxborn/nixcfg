# TODO

Ideas from comparing against [isabelroses/dotfiles](https://github.com/isabelroses/dotfiles).
Check each option with `nix eval` before adopting, and build `uranium` and
`tungsten` in full.

## done

- `workstation`: kernel behind `mkDefault`, 15s systemd timeouts, earlyoom.
- kernel: THP `always`/`defer` on workstations, `kexec_load_disabled` on all
  hosts, `iommu=pt` and `usbcore.autosuspend=-1` on `uranium`, boot cosmetics
  in `graphical-boot`. `legacy_tiocsti` and `dmesg_restrict` were already at
  the wanted values.
- nix: `keep-going`, `log-lines`, `warn-dirty`, `keep-outputs`,
  `keep-derivations`, `accept-flake-config = false`, host-overridable
  `min-free`/`max-free` (5G/20G on `uranium`).
- workstation home: `atuin` (local only), `lazygit`, `nix-your-shell`,
  `nix-output-monitor`, `dix`, `pwvucontrol`. `bat`, `direnv`, `eza` and
  `zoxide` were already there.
- boot: lanzaboote `bootCounting.initialTries = 3` on both workstations. The
  boot editor was already off. Verified on both after a reboot:
  `systemd-bless-boot` marks the booted entry good and strips its `+N` suffix,
  while unbooted entries such as tungsten's `nvidia-sync` specialisation keep
  `tries: 3 left`. The rollback path itself is untested.
- laptop: `tuned` battery detection and upower 20/5/2 were already the
  defaults. Critical action is now `PowerOff`, since the `HybridSleep` default
  needs a hibernation path that `noresume` and zram swap rule out.
- kernel: `kptr_restrict`, `fs.protected_fifos` and `fs.protected_regular` at 2
  on all hosts.
- `workstation`: empty `environment.defaultPackages` (drops perl, rsync, strace).
- atuin: argon's archive carries the `atuin` database. Verified by extracting
  `borgmatic/postgresql_databases/localhost/all` and finding its `history` and
  `users` tables.
- vaultwarden: argon's archive carries the `vaultwarden` SQLite dump. Verified
  with `borgmatic list --archive latest --find vaultwarden`, which found
  `borgmatic/sqlite_databases/localhost/vaultwarden`. It had been archived as
  live files before. The dump itself was listed, not extracted and opened.
- argon: removed the retired runner's `/var/lib/forgejo-runner`. Its Nix store
  volume was still being backed up and made borg warn about special files. Old
  archives keep carrying it until they age out of retention.
- backups: each host's borg key is confined to `borg serve --restrict-to-path`
  on its own repository on Helium, served on port 2200. Backups to Helium
  worked from every host after deploying Helium first, and `just restore-dr`
  for argon passed through the forced command. Other hosts' `restore-dr` runs
  are not recorded here. The keys are not append-only, so a host can still
  prune its own repository, and port 22 still reaches a shell by tailnet
  identity until the tailnet ACLs say otherwise.
- backups: the five rsync.net borg keys carry
  `command="borg14 serve --restrict-to-path /data1/home/de4388/borg/<host>",restrict`
  by hand, so a compromised host can no longer touch another host's offsite
  repository. Done on 2026-10-06. A backup to rsync.net and
  `just restore-dr` for argon passed afterward. The refusal of a key on another
  host's repository was not recorded as tested, and the keys are not
  append-only.
- `workstation`: `enableStrictShellChecks`. Tried on every host and reverted
  for servers, see the comment in `workstation.nix`. A clean build is not
  evidence: `nounset` broke `paperless-scheduler` on Helium at activation.
- `workstation`: journald caps, `udisks2`, speechd
  and nano off.

## open

- caddy: `secrets/tailscale/caddy.age` holds a Cloudflare `Zone:DNS:Edit`
  token encrypted to all five hosts, but only argon and helium use DNS-01.
  Narrow the recipients in `secrets/secrets.nix` and scope the token down.
  Also check that `tailscale/auth.age` is a tagged or single-use key, and
  review the tailnet ACLs for carbon, whose CI runner sits on a flat
  `trustedInterfaces = tailscale0` network.

Before any `just update` on a host running Postgres, compare
`datcollversion` with `pg_database_collation_actual_version(oid)` in
`pg_database`. A mismatch needs `REINDEX DATABASE` then `ALTER DATABASE ...
REFRESH COLLATION VERSION` first. Argon needed it, Helium did not.

## notes

- Never add BPF JIT hardening on `uranium`. `scx_lavd` needs the JIT.
- `brightnessctl` is deliberately absent, niri routes brightness through
  Noctalia for DDC. Revisit only if that changes.

## evaluated and skipped for now

- Declined: initrd zstd `-19` (ESP is not tight), `use-xdg-base-directories`,
  `flake-registry = ""`, `auto-allocate-uids`, `keep-sorted` hook. `jj` is
  parked until wanted, it needs a name and email for `programs.jujutsu`.
- Kernel hardening params (`slub_debug`, `page_poison`, `lockdown`,
  `module.sig_enforce`, `oops=panic`), `nohz_full`, forced PTI, `ptrace_scope=3`.
- `userborn` / `etc.overlay` / `nixos-init`. Possible clash with agenix
  activation, test on a throwaway host.
- `zswap` instead of zram. Needs a disk swap device.
- Check her git history for settings she reverted before adopting more.
