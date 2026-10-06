# TODO

Ideas from comparing against [isabelroses/dotfiles](https://github.com/isabelroses/dotfiles).
Check each option with `nix eval` before adopting, and build `uranium` and
`tungsten` in full.

## done

- `workstation`: kernel behind `mkDefault`, 15s systemd timeouts, earlyoom.
- `workstation`: `enableStrictShellChecks`, journald caps, `udisks2`, speechd
  and nano off.

## desktop and boot

- [ ] Strict shell checks on servers too. Workstations pass, the backups
      scripts are the likely failures.
- [ ] initrd zstd `-19 -T0` if the ESP gets tight.
- [ ] systemd-boot `bootCounting` and `editor = false`. Check lanzaboote support
      first, `uranium` uses it.
- [ ] Empty `environment.defaultPackages` on workstations. It drops `strace`
      and `perl` too, so decide that deliberately.

## laptop (`tungsten`)

- [ ] `tuned.ppdSettings.main.battery_detection = true`.
- [ ] `upower` low, critical and action percentages. Do not add a Hibernate
      critical action without dropping `noresume`.

## kernel

- [ ] THP via `boot.kernel.sysfs` (`enabled = always`, `defrag = defer`),
      workstations only. It can hurt Postgres and Redis.
- [ ] `usbcore.autosuspend=-1` on `uranium` only. Costs battery.
- [ ] `iommu=pt` alongside `intel_iommu=on` if not doing passthrough.
- [ ] sysctls: `dev.tty.legacy_tiocsti=0`, `kernel.kexec_load_disabled`,
      `kernel.dmesg_restrict`, `fs.protected_*`. Some may be NixOS defaults.
- [ ] boot cosmetics: `fbcon=nodefer`, `vt.global_cursor_default=0`, `logo.nologo`.
- Never add BPF JIT hardening on `uranium`. `scx_lavd` needs the JIT.

## nix settings

- [ ] `keep-going`, `log-lines = 30`, `warn-dirty = false`.
- [ ] `keep-outputs` and `keep-derivations` for direnv roots.
- [ ] `use-xdg-base-directories`, `flake-registry = ""`, `accept-flake-config = false`.
- [ ] `auto-allocate-uids` with `cgroups`.
- [ ] larger `min-free`/`max-free` (hers are 5G/20G) for `uranium`.

## software

Check `homes/` first, some may already be there.

- [ ] `nix-output-monitor`, `lix-diff` or `dix`.
- [ ] `atuin`, `zoxide`, `eza`, `bat`, `nix-your-shell`, `lazygit`, `jj`.
- [ ] `pwvucontrol`, `brightnessctl`.
- [ ] `keep-sorted` pre-commit hook.

## evaluated and skipped for now

- Kernel hardening params (`slub_debug`, `page_poison`, `lockdown`,
  `module.sig_enforce`, `oops=panic`), `nohz_full`, forced PTI, `ptrace_scope=3`.
- `userborn` / `etc.overlay` / `nixos-init`. Possible clash with agenix
  activation, test on a throwaway host.
- `zswap` instead of zram. Needs a disk swap device.
- Check her git history for settings she reverted before adopting more.
