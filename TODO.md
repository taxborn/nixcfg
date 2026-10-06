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
- `base`: `enableStrictShellChecks` on every host, all five build clean.
- `workstation`: journald caps, `udisks2`, speechd
  and nano off.

## atuin sync

- DNS needs nothing. The proxied `*.biscuits.at` CNAME already answers for
  `atuin.biscuits.at`, as it does for `vw` and `ntfy`.
- Collation: a glibc bump makes Postgres refuse `CREATE DATABASE` from a
  flagged `template1`. Argon is fixed. Helium will hit it on its next update,
  run `REINDEX DATABASE` then `ALTER DATABASE ... REFRESH COLLATION VERSION`
  for every database, with paperless stopped.
- [ ] Restore test: confirm the `atuin` database is in the next archive from
      argon (`pg_dumpall` should carry it).

## desktop and boot

- [ ] initrd zstd `-19 -T0` if the ESP gets tight.
- [ ] Empty `environment.defaultPackages` on workstations. It drops `strace`
      and `perl` too, so decide that deliberately.

- Never add BPF JIT hardening on `uranium`. `scx_lavd` needs the JIT.

## nix settings

- [ ] `use-xdg-base-directories` and `flake-registry = ""`. Skipped on purpose.
      The first moves `~/.nix-profile` state, the second breaks short refs
      like `templates#`. Decide if either is worth it.
- [ ] `auto-allocate-uids` with `cgroups`. Her config only enables the
      features without setting `auto-allocate-uids = true`, so it does nothing
      there. NixOS also still creates `nixbld` users.

## software

- [ ] `jj`. Needs a name and email decided before enabling `programs.jujutsu`.
- [ ] `keep-sorted` pre-commit hook. A no-op until package lists are annotated.
- [ ] `brightnessctl` is deliberately absent, niri routes brightness through
      Noctalia for DDC. Revisit only if that changes.

## evaluated and skipped for now

- Kernel hardening params (`slub_debug`, `page_poison`, `lockdown`,
  `module.sig_enforce`, `oops=panic`), `nohz_full`, forced PTI, `ptrace_scope=3`.
- `userborn` / `etc.overlay` / `nixos-init`. Possible clash with agenix
  activation, test on a throwaway host.
- `zswap` instead of zram. Needs a disk swap device.
- Check her git history for settings she reverted before adopting more.
