# Fleet CI on Forgejo Actions

Status: ready-for-human

## Problem

Nothing builds this repo except a deploy. `nixos-rebuild --target-host` builds
locally before it switches, so a broken host config never reaches that host —
that part is already safe. The gap is the other four hosts: change
`modules/nixos/base.nix`, deploy Carbon, and Tungsten can stop evaluating
without anything saying so until the next time that laptop is rebuilt. Weeks,
plausibly.

`nix flake check` evaluates each `nixosConfiguration`'s toplevel but does not
build it, so it catches eval errors and no build errors.

The runners are already provisioned for this and unused: `runner.nix` offers a
`nix` label backed by a pinned `docker.io/nixos/nix` image and a persistent
Podman volume mounted at `/nix`, specifically so a workflow building a NixOS
closure does not re-fetch it every run.

## Shape

`.forgejo/workflows/`, `runs-on: nix`, triggered on push to `main`.

Two jobs, or one job with two steps:

1. `nix flake check` — the pre-commit hook set over the whole tree.
2. Build every host closure:
   `nix build .#nixosConfigurations.<host>.config.system.build.toplevel`
   for each of the five. Derive the list from the roster once
   [03](./03-host-roster.md) lands; hardcode until then.

### On Argon

Not Helium. Helium is a four-core NUC serving the borg repository every other
host writes to, and Paperless. It is the last thing here that should contend for
I/O. Argon is 8 vCPU / 16 GB and hosts the monitoring stack, which is worth
protecting but not by starving it:

```nix
myNixOS.services.forgejo.runner.settings.container.options =
  "--memory=12g --cpus=6";
```

`capacity` is 3 with no limits today, so one push can currently take the whole
machine.

### Constraints that shape the workflow

- **The `nix` image carries no node**, so no `uses:` step runs under it. The
  workflow does its own `git clone`. This is documented in `runner.labels` as a
  deliberate trade and is not a thing to work around.
- **Unfree is required** — Tungsten and Uranium pull nvidia and Steam.
  `nixpkgs.config.allowUnfree` is set in `modules/flake/hosts.nix`, so the
  configurations carry it; the builder needs no extra flag.
- **No job may garbage-collect the shared store.** See
  [02](./02-runner-store-gc-timer.md) and the `nixStoreVolume` comment in
  `runner.nix` for why this is a real hazard rather than a preference.
- The runner reaches the forge at `git.<tailnet>` and rewrites the job's
  `GITHUB_SERVER_URL` from that connection, so checkout takes the tailnet path
  and never crosses Cloudflare.

## Notification

Forgejo's built-in email. SMTP to `hello@taxborn.com` already works via
`secrets/forgejo/mail.age`.

ntfy would be the better destination — it is where every other fleet alert goes
— but the topic is encrypted to Argon's *host* key and a job container cannot
read an agenix secret. Routing there means a Forgejo Actions secret holding a
second copy of the topic, which is a new place for it to leak from. Not worth
one notification hop. Revisit if email proves too quiet.

## Not in scope

This does not gate anything. There is no branch protection and `just update`
does not consult a commit status. See ADR-0002.

## Done when

A push to `main` that breaks any host's evaluation or build produces a red run
and an email, and a green run means all five hosts build.

## Comments

**Implemented, not yet deployed.**

- `.forgejo/workflows/build.yaml` — one job, `runs-on: nix`, hand-rolled
  checkout, `nix flake check`, then the five closures in a loop that builds all
  of them before reporting.
- `hosts/argon/default.nix` — `capacity = 1`, `containerOptions = [ "--memory=12g" "--cpus=6" ]`.
- `modules/nixos/services/forgejo/runner.nix` — new `containerOptions` option;
  see below.

### The module needed fixing first

This issue said to set `settings.container.options`. That would have broken the
shared store. `container.options` is a single string and `settings` is merged
with `recursiveUpdate`, so writing it replaces the `--volume=<store>:/nix`
mount rather than adding to it — every job keeps working and silently re-fetches
its whole closure. The module's own example demonstrated the bug.

Added `containerOptions` (a list, composed with the mount) and pointed the
`settings` and `capacity` descriptions at it. Verified against the generated
config on both runner hosts: Argon carries mount + limits, Helium carries the
mount alone.

### Also chose capacity 1 on Argon

Not in the original issue. The limits are per container, so `capacity = 3`
against `--memory=12g` claims 36g on a 16 GB host, which is not a limit. One run
at a time also stops two pushes contending over the same store for the same
derivations.

### Verified

`nix flake check` passes on the current tree, so the first CI step is green
before it ever runs. The workflow YAML parses. Nothing has been deployed.

### Remaining

1. `just update argon` **while no run is in flight** — see the postmortem below
   for why the order matters and why it now blocks rather than killing.
2. Then commit `.forgejo/` (Forgejo cannot see an untracked workflow), or
   re-run the failed run if it is already committed.
3. Expect the first run to be slow and possibly to hit the runner's one-hour
   job timeout: the store volume starts empty and five full closures land in it.
   A re-run continues from what the first left behind, because the volume
   persists. That is the fix, not a config change.
4. Unverified: whether this repo is public on the forge. The checkout uses
   `secrets.GITHUB_TOKEN`, which works either way, so this only matters if the
   step fails to authenticate.

## Postmortem — run 3, killed after ~5 minutes

Not a build failure. `just update argon` restarted `forgejo-runner` three
minutes into the run and systemd killed it mid-job.

```
07:07:30  runner picks up task 48 (nixcfg, run 3)
07:10:46  systemd: "Stopping Forgejo Actions runner..."          <- just update argon
07:10:46  runner:  "waiting [runner].shutdown_timeout=1h0m0s"
07:12:16  systemd: "State 'stop-sigterm' timed out. Killing."    <- 90s later
07:12:16  SIGKILL; unit latches failed; job lost and not requeued
07:12:19  runner restarts clean
```

Two causes.

**The issue's own step order was wrong.** It said to commit `.forgejo/` and then
deploy. Committing the workflow is what triggers the run, so that sequence
collides by construction. Corrected above: deploy first.

**`shutdown_timeout` had never worked.** The module set it to `1h` and
documented that a rebuild should not kill a running job, but systemd's default
`TimeoutStopSec` is 90 seconds — it SIGKILLed the runner long before the hour
the runner had announced. This predates the CI work; it was simply invisible
until something restarted the unit while a job was running.

Fixed by deriving all three values from one `jobTimeoutSeconds`, with
`TimeoutStopSec` a minute above the runner's own grace period so the runner is
always what decides to give up. Verified: `TimeoutStopSec = 3660` against
`shutdown_timeout: 3600s`.

**Consequence, and it is not free**: a rebuild of Argon now *blocks* for as long
as a job is running, up to an hour, with no output while it waits. On a host
that builds the fleet on every push that will happen. The alternatives, if that
proves worse than losing a job, are to lower `jobTimeoutSeconds`, or to make the
kill honest by dropping both to ~90s and dropping the comment's promise.
