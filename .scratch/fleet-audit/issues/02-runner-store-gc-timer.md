# Automate the CI store garbage collection

Status: ready-for-agent

Blocked by: 01

## Problem

Once [01](./01-forgejo-actions-ci.md) lands, every push builds five NixOS
closures into the runner's shared `/nix` volume. Nothing collects it.

It cannot be collected from inside a job, and the reason is documented at length
on `nixStoreVolume` in `runner.nix`: concurrent jobs are separate containers
with separate pid namespaces, all counting from 1, so Nix's temproot files
collide and a collector inside one job will delete paths a live build in another
is standing on.

`just runner-gc <host>` does it correctly from outside — stop the runner, run
`nix store gc` in a throwaway container against the volume, restart — but it is
manual, and it is the kind of manual that gets remembered the week after Argon's
320 GB fills and takes Prometheus and Loki down with it.

## Shape

A systemd timer on Argon running weekly, doing what `just runner-gc` does:

```
systemctl stop forgejo-runner
podman run --rm -v <storeVolume>:/nix <nixImage> nix store gc
systemctl start forgejo-runner
```

Details that matter:

- **Read the volume and image names from the module**, not by recomputing them.
  `runner.storeVolume` is `readOnly` and exists for exactly this — it is derived
  from `nixImage`, and a bump changes the volume name deliberately.
- **Restart the runner even on failure.** The justfile uses `trap ... EXIT`; the
  unit wants the equivalent, so a failed collection does not leave the forge
  without a runner. `ExecStopPost` or a `||`-guarded restart.
- **Podman is rootless**, reached through the `forgejo-runner` user's own
  runtime directory, which exists between boots only because that user lingers.
  The unit needs `XDG_RUNTIME_DIR` set the way the justfile sets it.
- **Stopping can block for up to `shutdown_timeout`** (1h, kept equal to
  `timeout`) if a job is mid-flight. Schedule it when the forge is quiet and
  give the unit a `TimeoutStopSec` that tolerates it.
- Bumping `nixImage` orphans the old volume by design. The timer collects the
  current one; `podman volume prune` reclaims the rest, and that stays manual.

## Done when

Argon's CI store is bounded without anyone remembering to bound it, and a
collection that fails still leaves a running runner.

## Comments

Argon's runner is now `capacity = 1` (see [01](./01-forgejo-actions-ci.md)),
which makes the stop half of this cheaper than the issue assumes: at most one
job can be in flight, so the worst-case wait on `systemctl stop` is one
`shutdown_timeout` rather than three overlapping ones. Helium is unchanged at 3.
