# TODO

Ideas from comparing against [isabelroses/dotfiles](https://github.com/isabelroses/dotfiles).
Check each option with `nix eval` before adopting, and build `uranium` and
`tungsten` in full.

## open

Most of this list comes from the 2026-11-09 config and security review. It is
ordered by how much each item shrinks the worst case.

- minecraft: the worlds are moved to `/var/lib/minecraft/<name>`. Once players
  have connected, remove `/home/taxborn/public/<name>` on argon and carbon. The
  sandbox has not run against a live pack, so if a mod fails read the journal
  for the denied path or address family before loosening anything.
- minecraft: move `mnb` off argon. The service account closes the path to
  root, but an internet-facing JVM with third-party mods still shares a host
  with Vaultwarden, the PDS master key and the knot. Carbon already runs
  one server and holds far less.
- tailscale: the tailnet is one flat trust zone and its policy is not in this
  repo. Every host trusts `tailscale0`, runs Tailscale SSH and has IP
  forwarding on, so "tailnet only" means "any tailnet node". Check the policy
  file in here and apply it from here. Tag the hosts, with carbon as `tag:ci`
  allowed to reach helium 2200 and helium 3100 and nothing else.
  Allow Tailscale SSH from the workstations only. Check that
  `tailscale/auth.age` is a tagged or single-use key. Set
  `useRoutingFeatures` to `"client"` unless a host is an exit node.
- monitoring: two outages cannot page anyone. Alerts leave helium through
  ntfy on argon, so `InstanceDown` for argon has nowhere to go, and nothing
  outside helium notices when helium stops. Add an email receiver for
  `severity="critical"` through the Fastmail relay, and an always-firing rule
  that pings an outside dead-man service.
- helium: its disk is plain btrfs and it is the one server in a house, with
  the Paperless archive on it. Decide between leaving it, for unattended
  reboots, and LUKS with TPM2 unlock. Record the answer in the README's
  "do not" list either way.

Before any `just update` on a host running Postgres, compare
`datcollversion` with `pg_database_collation_actual_version(oid)` in
`pg_database`. A mismatch needs `REINDEX DATABASE` then `ALTER DATABASE ...
REFRESH COLLATION VERSION` first. Argon needed it, Helium did not.

## notes

- Never add BPF JIT hardening on `uranium`. `scx_lavd` needs the JIT.
- `brightnessctl` is installed on tungsten only, in the host file. Niri routes
  brightness keys through Noctalia, so the package is for manual use on the
  laptop panel. External monitors need DDC, which is not wired up.

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
