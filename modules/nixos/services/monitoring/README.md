# monitoring

Prometheus, Loki, Alertmanager and Grafana on Helium. Exporters and Alloy on
every host. Alerts arrive as ntfy pushes through Argon's ntfy.

| File | What is in it |
| --- | --- |
| `default.nix` | the client: node_exporter, smartctl_exporter, Alloy |
| `server.nix` | Prometheus, Alertmanager, the ntfy bridge, Loki, Grafana |
| `alerts.nix` | the alert rules |
| `dashboards.nix` | the provisioned dashboards |

The earlier version of this stack lived on Argon and was removed in `f4012fc`.
This one keeps its design and moves the server, so most of the reasoning in the
comments is carried over.

## how a host gets monitored

It is on the tailnet, and `base` enables the client, so every host is covered
including the workstations. `mySnippets.tailnet.tailscaleIPs` is the roster and
the server derives its scrape targets from it. `mySnippets.monitoring` refines
that without changing whether a host is monitored:

- `alwaysOn` hosts land in the `node` job and are covered by `InstanceDown`.
  Everything else is `node-intermittent`, because a closed lid is not an outage.
- `physicalDisks` hosts run and are scraped for `smartctl_exporter`.

Workstations behave differently from servers in two ways. They are never
alerted on for being down, and their Alloy keeps a cursor, so a laptop that was
off the tailnet ships the gap when it returns, up to the week Loki accepts.

## what listens where

Nothing here is in `allowedTCPPorts`. Reachability is decided by which address a
process binds. Ports live in `mySnippets.monitoring.ports`, and Grafana's is in
`networkMap`.

| Service | Address | Reachable from |
| --- | --- | --- |
| Grafana | `127.0.0.1:3009` | Caddy, at `grafana.biscuits.at` on the tailnet |
| Prometheus | `127.0.0.1:9090` | Grafana only |
| Alertmanager | `127.0.0.1:9093` | Prometheus only. Clustering is off. |
| alertmanager-ntfy | `127.0.0.1:8111` | Alertmanager only |
| Loki | `<helium tailnet IP>:3100` | the tailnet, for every Alloy |
| node_exporter | `<host tailnet IP>:9100` | the tailnet |
| smartctl_exporter | `<host tailnet IP>:9633` | the tailnet |
| mc-monitor, process-exporter | `<host tailnet IP>:9150`, `:9256` | the tailnet. mc-monitor binds every interface, so its unit denies all but loopback and the tailnet range. |

**Accepted, not overlooked:** Loki runs with `auth_enabled = false`, so any
tailnet peer can push logs under any label. That is the same trust boundary as
everything else on the tailnet. Revisit if the tailnet ever holds a device
someone else administers.

## the cold-boot race

A unit binding a Tailscale address can start before `tailscaled` has assigned
one and die with `EADDRNOTAVAIL`. Ordering after `tailscaled.service` is not
enough, so the exporters and Loki also set `StartLimitIntervalSec = 0`. Without
it systemd latches the unit failed after five tries in ten seconds. After
touching this, reboot a host and confirm the exporter comes back by itself.

## retention and backups

- **Prometheus:** 90 days or 16 GB, whichever comes first.
- **Loki:** 30 days. This needs `retention_period` and the compactor's
  `retention_enabled`. Either alone deletes nothing.
- **Backups:** none of the three stores is archived. Helium's `extraExcludes`
  name `/var/lib/prometheus2`, `/var/lib/loki` and `/var/lib/grafana`. None of
  them overlaps borgmatic's dump staging path.

## dashboards

Provisioned from the store with `allowUiUpdates = false`, so an edit in the
browser is discarded on restart. Editing a dashboard means editing
`dashboards.nix`. There are five: Fleet Overview, Node Exporter Full (grafana.com
1860, pinned by hash), Disk & SMART, Logs with host and unit variables, and
Minecraft for `mavs-updated`. The Minecraft metric names come from mc-monitor and
process-exporter documentation and were not checked against a live server, so
after the first deploy look at `curl <host tailnet IP>:9150/metrics` and fix
any panel that reads No data.

Bumping Node Exporter Full:

```bash
curl -s https://grafana.com/api/dashboards/1860 | jq .revision
nix store prefetch-file https://grafana.com/api/dashboards/1860/revisions/<n>/download
```

## alerts

`SystemdUnitFailed` pays for the stack: it turns any failing unit into a
notification without a per-service rule. `promtool` validates the rules at build
time, but it cannot tell whether a metric name is real, so check a new one
against live exporter output.

Alerts go to the `alerts` topic on Argon's ntfy using the shared write-only
publisher token (`secrets/ntfy/token.age`). That server denies everything by
default, so `secrets/ntfy.age` must grant that token's user write access to the
topic. A missing grant is a 403 that appears only in the bridge's journal.

## first deploy

Needs three things outside this repo, in this order:

1. Create the secrets (`secrets/README.md#working-with-them`), each readable by
   Helium and the YubiKey: `grafana/admin-password.age` and
   `grafana/secret-key.age`. The secret key is any long random string.
2. Add the ntfy grant above, and subscribe to the `alerts` topic.
3. Add a DNS-only `grafana.biscuits.at` A record pointing at Helium's tailnet
   address, as for `docs.biscuits.at`.

Deploy so the exporters answer before anything scrapes them, then:

```bash
systemctl status prometheus-node-exporter alloy      # every host
systemctl status prometheus grafana loki alertmanager alertmanager-ntfy-auth alertmanager-ntfy   # helium
curl -s localhost:9090/api/v1/targets \
  | jq -r '.data.activeTargets[] | "\(.labels.job) \(.labels.instance) \(.health)"'
curl -s "http://$(tailscale ip -4):3100/loki/api/v1/label/host/values" | jq
```

Then prove delivery rather than trusting the config:

```bash
systemd-run --unit=alert-canary --service-type=oneshot false
# about 15 minutes later a push should arrive; then:
systemctl reset-failed alert-canary
```

The resolved notification is half the check.
