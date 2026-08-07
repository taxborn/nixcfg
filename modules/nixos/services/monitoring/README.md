# monitoring

Prometheus, Loki, Alertmanager and Grafana on Argon; exporters and Alloy
everywhere. Alerts arrive as ntfy pushes.

| File | What is in it |
| --- | --- |
| `default.nix` | the client — node_exporter, smartctl_exporter, Alloy |
| `server.nix` | Prometheus, Alertmanager, the ntfy bridge, Loki, Grafana |
| `alerts.nix` | the alert rules |
| `dashboards.nix` | the four provisioned dashboards |

## how a host gets monitored

It is on the tailnet. That is the whole mechanism.

`mySnippets.tailnet.tailscaleIPs` is the roster. `base.nix` turns the client on
for every host, and the server derives its scrape targets from the same map, so
there is one list and nothing to keep in step with it. Two sublists refine what
happens to a host, not whether it is monitored:

- **`alwaysOn`** — hosts where being down is a fault. These land in the `node`
  job; everything else goes to `node-intermittent`, and `InstanceDown` covers
  `node` alone. Tungsten is a laptop and Uranium is a desktop, so `up == 0` is
  their ordinary state.
- **`physicalDisks`** — hosts with disks that answer a SMART command. Decides
  both whether `smartctl_exporter` runs and whether it is scraped. The OVH
  instances are excluded because virtio devices report nothing; `default.nix`
  asserts this agrees with `services.smartd.enable`.

Adding a host to the fleet means adding it to `tailscaleIPs` and deciding those
two questions. There is no third place to remember.

## what listens where

Nothing here is in `allowedTCPPorts`. Reachability is decided by which address a
process binds, which is the same doctrine the Forgejo module and the tailnet
vhosts follow — the firewall is not the boundary, the absence of a socket is.

| Service | Address | Reachable from |
| --- | --- | --- |
| Grafana | `127.0.0.1:3003` | Caddy only, which serves it at `grafana.<tailnet>` |
| Prometheus | `127.0.0.1:3004` | Grafana only |
| Alertmanager | `127.0.0.1:3005` | Prometheus only |
| alertmanager-ntfy | `127.0.0.1:3006` | Alertmanager only |
| Loki | `<argon tailnet IP>:3007` | the tailnet — four remote Alloys push to it |
| node_exporter | `<host tailnet IP>:9100` | the tailnet |
| smartctl_exporter | `<host tailnet IP>:9633` | the tailnet |

Only Loki and the exporters are on the tailnet, because only they have a remote
caller. The previous version of this stack put Prometheus there too, which
published every metric from every host to every device on the tailnet in
exchange for nothing.

**Accepted, not overlooked:** Loki runs with `auth_enabled = false`, so any
tailnet peer can push logs under any label. That is the same trust boundary as
everything else reachable on the tailnet, and closing it would mean distributing
a shared credential to five hosts to defend against an attacker who is already
inside. Revisit if the tailnet ever holds a device someone else administers.

## the cold-boot race

Anything binding a specific Tailscale address can start before `tailscaled` has
assigned one and die with `EADDRNOTAVAIL`. Ordering after `tailscaled.service`
is not enough on its own — the unit being *started* does not mean an address
exists yet — and these units already restart on failure, so the part that
actually matters is `StartLimitIntervalSec = 0`. Without it systemd's default of
five starts in ten seconds latches the unit failed after a few seconds of
retrying and leaves it dead until someone notices.

This is applied to both exporters and to Loki. It is the reason a reboot is on
the checklist below.

## retention

Both stores are bounded, and both bounds are chosen rather than inherited.

- **Prometheus** — 90 days or 16 GB, whichever comes first.
- **Loki** — 30 days, which needs *two* settings: `retention_period` only marks
  chunks expired, and nothing deletes them unless the compactor has
  `retention_enabled`. The previous version set neither and grew without limit.

Neither store is backed up (`hosts/argon/default.nix` excludes both). A metrics
store restored from last night is a gap-free record of a machine that no longer
exists.

## dashboards

Four, all provisioned from the store with `allowUiUpdates = false` — an edit in
the browser is accepted and then discarded on the next restart, so editing a
dashboard means editing `dashboards.nix`.

- **Fleet Overview** — every host at once. The pane `Node Exporter Full` cannot
  give, since that one is driven by a host picker.
- **Node Exporter Full** — grafana.com dashboard 1860, fetched at build time
  against a pinned revision and hash rather than vendored. A bump is two lines:

  ```bash
  curl -s https://grafana.com/api/dashboards/1860 | jq .revision
  nix store prefetch-file https://grafana.com/api/dashboards/1860/revisions/<n>/download
  ```

  The `jq` pass in `dashboards.nix` binds its datasource variable to the
  provisioned UID and hides the picker. Upstream ships that variable with an
  empty `current`, so without the patch the dashboard renders blank until
  someone chooses a datasource, and the choice is stored per-user in Grafana's
  database rather than in the file.
- **Disk & SMART** — drive health, wear, temperature, capacity.
- **Logs** — the journal, with host and unit variables.

## alerts

Fifteen rules in `alerts.nix`, in three groups. `SystemdUnitFailed` is the one
that pays for the stack: it turns every failure this config can already have
into a notification without a per-service rule — a backup that did not run, a
runner that died, a Caddy that would not start.

`promtool` validates these at build time, so a malformed expression fails
`nixos-rebuild`. What it cannot check is whether a metric name is real — a typo
there parses fine and then never fires. Every name used was verified against
live `node_exporter` and `smartctl_exporter` output, and a new rule should be
too.

Two details worth keeping if the rules are edited:

- Filesystem rules collapse on `(instance, device)`. Every btrfs subvolume
  reports the pool's free space, so Uranium's root is six identical series and
  the uncollapsed form sends six notifications for one full disk.
- `DiskTempHigh` filters `temperature_type="current"`. The exporter also
  publishes `drive_trip`, the manufacturer's shutdown threshold, which sits
  around 85–100 °C and would satisfy the comparison permanently on a healthy
  drive.

### changing where alerts go

The ntfy topic is a password on a public instance, so it lives in
`secrets/ntfy/alertmanager.age` as a YAML fragment rather than beside the base
URL in the module:

```yaml
ntfy:
  notification:
    topic: <topic>
```

Read it back with `agenix -d ntfy/alertmanager.age -i ~/.config/age/yubikey-identity.txt`,
and subscribe to that topic in the ntfy app. `myNixOS.services.monitoring.server.ntfyBaseUrl`
points at a self-hosted instance if ntfy.sh ever stops being good enough.

## first deploy

Grafana's admin password is in `secrets/grafana/admin-password.age`; read it the
same way. The account is `admin`, and sign-up is disabled.

Deploy the client everywhere before the server, so the exporters answer before
anything scrapes them:

```bash
# on each host
systemctl status prometheus-node-exporter prometheus-smartctl-exporter alloy
curl -s "http://$(tailscale ip -4):9100/metrics" | head

# on argon
systemctl status prometheus grafana loki alertmanager alertmanager-ntfy
curl -s localhost:3004/api/v1/targets \
  | jq -r '.data.activeTargets[] | "\(.labels.job) \(.labels.instance) \(.health)"'
curl -s "http://$(tailscale ip -4):3007/loki/api/v1/label/host/values" | jq
```

Then reboot a host and confirm its exporter comes back on its own — the bind
race above only shows up on a cold boot:

```bash
systemctl show prometheus-node-exporter -p NRestarts -p ActiveState
```

`ActiveState=active` is the pass. A nonzero `NRestarts` is expected and fine;
that is the retry working.

Finally, prove delivery rather than trusting the config:

```bash
systemd-run --unit=alert-canary --service-type=oneshot false
# ~2 minutes later a push should arrive; then:
systemctl reset-failed alert-canary
```

The resolved notification is half the check. An alert that fires and never
visibly clears trains you to ignore the stream.
