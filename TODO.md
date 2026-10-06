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
  boot editor was already off. After the first reboot, `bootctl list` should
  show the new entry as good, not counting down.
- laptop: `tuned` battery detection and upower 20/5/2 were already the
  defaults. Critical action is now `PowerOff`, since the `HybridSleep` default
  needs a hibernation path that `noresume` and zram swap rule out.
- kernel: `kptr_restrict`, `fs.protected_fifos` and `fs.protected_regular` at 2
  on all hosts.
- `workstation`: empty `environment.defaultPackages` (drops perl, rsync, strace).
- atuin: argon's archive carries the `atuin` database. Verified by extracting
  `borgmatic/postgresql_databases/localhost/all` and finding its `history` and
  `users` tables.
- `base`: `enableStrictShellChecks` on every host, all five build clean.
- `workstation`: journald caps, `udisks2`, speechd
  and nano off.

## open

- Helium collation: a glibc bump makes Postgres refuse `CREATE DATABASE` from a
  flagged `template1`. Argon is fixed. Helium will hit it on its next update,
  run `REINDEX DATABASE` then `ALTER DATABASE ... REFRESH COLLATION VERSION`
  for every database, with paperless stopped.
- Reboot uranium and tungsten, then check `bootctl list` for boot counting.

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
