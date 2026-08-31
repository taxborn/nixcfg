# Deploy staleness metric

Status: ready-for-agent

Blocked by: 03

## Problem

`modules/nixos/base.nix` sets `system.configurationRevision` from `self.rev`, so
every host knows which commit it is running. Nothing exports it. Grafana scrapes
all five hosts and cannot answer "which of these is behind `main`".

Deploys are one host at a time by hand (`just update <host>`, and that stays —
see ADR-0002), so a shared-module change means remembering which hosts you got
to. At eight servers that is not a thing to hold in your head.

## Shape

### Export it

`textfile` is not in `enabledCollectors` today — the list is `systemd`,
`processes`, `interrupts`. Add it, give node_exporter a textfile directory, and
write one `.prom` file at activation.

Two series:

```
nixcfg_deploy_timestamp_seconds <self.lastModified>
nixcfg_configuration_revision_info{rev="<self.rev>"} 1
```

Both values are available at build time — flake `self` carries `lastModified`
and `rev` — so nothing shells out to git at runtime. Handle the dirty-tree case:
`self.rev` is absent then, and `base.nix` already falls back through
`dirtyRev`.

The timestamp is the load-bearing one. A rev label alone cannot be ranked or
thresholded; you would read it off a table and do the arithmetic yourself. The
`_info` series carries the rev for the dashboard, and its churn is acceptable —
one new series per deploy per host, which Prometheus ages out.

### Alert on it

`time() - nixcfg_deploy_timestamp_seconds > 14d`, **restricted to the `node`
job**. Always-on hosts only.

Tungsten is a laptop and Uranium is a desktop; both are asleep for weeks and
being behind is their ordinary state. This is the same reasoning that already
splits `node` from `node-intermittent` in `alwaysOn` — an alert that fires every
holiday is an alert that gets muted, and muting it costs the one that mattered.

### Deploy to more than one host at once

`just update-all`, looping the always-on hosts from the roster. Sequential, not
parallel — the failure mode worth avoiding is discovering three hosts are broken
at the same time.

## Done when

A Grafana panel ranks hosts by how far behind they are, and a server left behind
for two weeks says so without being asked.
