# TODO

## open

- minecraft: the worlds are moved to `/var/lib/minecraft/<name>`. Once players
  have connected, remove `/home/taxborn/public/<name>` on argon and carbon. The
  sandbox has not run against a live pack, so if a mod fails read the journal
  for the denied path or address family before loosening anything.
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

Before any `just update` on a host running Postgres, compare
`datcollversion` with `pg_database_collation_actual_version(oid)` in
`pg_database`. A mismatch needs `REINDEX DATABASE` then `ALTER DATABASE ...
REFRESH COLLATION VERSION` first.

## notes

- Never add BPF JIT hardening on `uranium`. `scx_lavd` needs the JIT.
- `brightnessctl` is installed on tungsten only, in the host file. Niri routes
  brightness keys through Noctalia, so the package is for manual use on the
  laptop panel. External monitors need DDC, which is not wired up.
