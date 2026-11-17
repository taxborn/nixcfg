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
including the workstations. `homelab.hosts` is the roster and
the server derives its scrape targets from it. `homelab.monitoring` refines
that without changing whether a host is monitored:

- `alwaysOn` hosts land in the `node` job and are covered by `InstanceDown`.
  Everything else is `node-intermittent`, because a closed lid is not an outage.
- `physicalDisks` hosts run and are scraped for `smartctl_exporter`.

Workstations behave differently from servers in two ways. They are never
alerted on for being down, and their Alloy keeps a cursor, so a laptop that was
off the tailnet ships the gap when it returns, up to the week Loki accepts.

## what listens where

Nothing here is in `allowedTCPPorts`. Reachability is decided by which address a
process binds. Ports live in `homelab.monitoring.ports`, and Grafana's is in
`homelab.services`.

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

1. Create the secrets (see [secrets](./secrets.md#working-with-them)), each readable by
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

## design notes

Reasoning that used to sit beside the code.

### server

- **Prometheus** listens on loopback. Grafana is its only client and runs on the
  same host, so putting the TSDB on the tailnet would expose every metric to
  every device for nothing. Use Grafana's Explore tab or an SSH tunnel.
- Scrape interval is 30s. The 1m default misses CPU spikes, and 15s would
  double storage with nothing needing it. SMART is scraped every 5m, since the
  data changes over hours and each scrape wakes the disks.
- Retention is 90 days or 16 GB, whichever comes first. The size cap is what
  stops a cardinality bug from filling the disk.
- Each scrape target gets its own `instance` label (`helium`, not
  `100.64.1.0:9100`). That only works because each `static_configs` entry
  holds exactly one target.
- Hosts in `alwaysOn` land in the `node` job and the rest in
  `node-intermittent`. `InstanceDown` covers `node` only, because a closed lid
  is not an outage, and a rule that fires every time one closes gets muted.
- **Alertmanager** listens on loopback, and its clustering is turned off. The
  nixpkgs defaults would listen on every interface and gossip on 9094.
- Alerts are grouped by alert and host, repeat every 12h rather than 4h since
  nothing here is on call, and send resolutions.
- The webhook URL must end in `/hook`. Anything else gets a 404 that
  Alertmanager logs and ignores, so the alert never reaches a phone.
- **alertmanager-ntfy** turns the webhook JSON into a readable push. It reuses
  the backup clients' write-only publisher token, rendered by a root
  `alertmanager-ntfy-auth` unit into a tmpfs YAML fragment, because the bridge
  runs under DynamicUser and has no stable uid to own an agenix file.
- **Loki** has no multi-tenancy, so any tailnet peer can push any label. That
  is the tailnet's trust boundary, and it was accepted on purpose. Loki's HTTP
  listener is the only tailnet socket on the server. The gRPC ring stays on
  loopback, and its port is pinned because the ring advertises the configured
  value, so `0` would leave every client dialling `127.0.0.1:0`.
- Loki retention needs `retention_enabled` on the compactor as well as
  `retention_period`. With only the period set, Loki grows until the disk
  fills.
- Samples older than a week are rejected, so a host with a bad clock or a long
  offline buffer cannot write into the past. Per-host ingestion is capped to
  limit a service stuck in a log loop. `volume_enabled` powers Explore's volume
  histogram.
- The Loki ruler sends LogQL alerts to the same Alertmanager. Its rules live
  under the `fake` tenant directory, which is the tenant name when auth is off.
  The PDS login-failure rule matches the endpoint as well as the 401, and
  groups by vhost rather than client, since `client_ip` can be forged through
  Cloudflare.
- **Grafana** listens on loopback behind Caddy. The admin password is declared
  through `$__file{}` rather than set at first login, which would leave it only
  in the mutable database. Datasource UIDs are pinned so provisioned dashboards
  can name them. `deleteDatasources`, `allowUiUpdates = false` and
  `disableDeletion` keep the store authoritative. Editing a dashboard means
  editing `dashboards.nix`. nixpkgs 26.05 dropped Grafana's shared default
  secret key, so one is provided. Rotating it only costs sessions.
- Prometheus, Loki and Grafana state is excluded from backups. A restored
  metrics store records a machine that no longer exists, and Grafana's SQLite
  file would be copied torn.

### client

- Exporters bind the host's own tailnet address. `tailscale0` is trusted, so the
  ports are reachable from the tailnet and nowhere else. Loopback would not
  work, since another host does the scraping.
- node_exporter adds the `systemd`, `processes` and `interrupts` collectors.
  `systemd` is the valuable one: it turns every unit failure into one alert
  rule.
- smartctl_exporter runs only on `physicalDisks` hosts and scans for devices
  itself, because `/dev/sdX` paths are not stable. The client asserts that
  `physicalDisks` and `services.smartd.enable` agree.
- Alloy ships the journal plus Caddy's `direct-*` access logs. The only labels
  are `host`, `unit` and `vhost`. Status, IP and URI stay in the JSON line,
  because as labels they would make one stream per client. Rotated files are
  excluded, or every rotation would re-ship a day of logs. Alloy joins the
  `caddy` group to read the `0640` logs. Its config is written to `/etc`
  because the nixpkgs module derives reload triggers from there, and a store
  path would restart Alloy on every rebuild.

### alerts

- Filesystem alerts use an allowlist of real filesystem types. A denylist grows
  a hole every time a new tmpfs or fuse shim appears.
- btrfs subvolumes all report the pool's free space, so the ratio is collapsed
  with `min by (instance, device)`. Otherwise one full disk is six alerts.
- `SystemdUnitFailed` covers most failures. `BackupStale` covers what it cannot
  see: a timer that stopped firing leaves no failed unit behind. It keys on the
  timer's last trigger, and only for the `node` job.
- Rules on monotonic counters (OOM kills, btrfs device errors, NVMe media
  errors) alert on the increase, so each event reports once.
- Disk-fill prediction also requires under 30% free, since a six-hour trend on
  an empty disk crosses zero after any large build.
- The read-only filesystem alert excludes `/nix/store`, which NixOS bind-mounts
  read-only. Left in, it never resolves and holds the notification path open
  until the receiver rate-limits everything else.
- `node_md_degraded` exists because mdadm's only other notification is mail to
  a local mailbox nobody reads.
- The SMART temperature rule filters `temperature_type="current"`. The exporter
  also publishes the drive's trip point, which would always match.
- Steal time is watched on the OVH instances, which share hardware.
- Rules are emitted with `builtins.toJSON` and checked by `promtool` at build
  time. promtool cannot check metric names, so every name was verified against
  live exporter output.

### dashboards

- `realFs` must match the selector in `alerts.nix`. They are kept in step by
  hand.
- The Node Exporter Full dashboard (1860) is fetched at a pinned revision and
  hash rather than vendored as a 15,000-line JSON file. To refresh it, run
  `curl -s https://grafana.com/api/dashboards/1860 | jq .revision`, then
  `nix store prefetch-file` the revision's download URL.
- The fleet overview exists because 1860 shows one host at a time. Its alert
  count uses `or vector(0)`, so "nothing firing" reads as 0 rather than "No
  data".
- Provisioned dashboards have `id = null` and `editable = false`, so the UI
  says up front that edits will not stick.
- The Minecraft dashboard is hardcoded to Carbon's server and scoped to
  `instance="carbon"`, because Argon runs one too.
