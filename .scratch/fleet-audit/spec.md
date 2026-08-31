# Fleet audit

An audit of this repo against what it will need as the fleet grows. The premise,
settled first because everything else hangs off it: **growth is servers**. One
more VPS, perhaps one more box like Helium. The workstation set is closed at
Tungsten and Uranium.

## What the audit did not find

No defect in backups, monitoring, secrets scoping, disko, or lanzaboote. The
restore ladder in the justfile tests real repositories over the real network
with the real yubikey, which is more than most fleets this size have. Nothing
below is a rescue.

## What it found

Five issues, in the order they should land. The order matters: CI is first
because it is independent of the two refactors and is what makes them safe to
perform.

| #                                              | Issue                       | Why                                                                                                 |
| ---------------------------------------------- | --------------------------- | --------------------------------------------------------------------------------------------------- |
| [01](./issues/01-forgejo-actions-ci.md)        | Fleet CI on Forgejo Actions | A shared-module change can break a host nobody rebuilds for weeks. Nothing catches it today.          |
| [02](./issues/02-runner-store-gc-timer.md)     | Automate the CI store GC    | Five closures per push into a volume nothing collects. Fills Argon, takes Prometheus down with it.    |
| [03](./issues/03-host-roster.md)               | Single host roster          | Adding a host means editing five parallel lists. Omitting one fails silently.                        |
| [04](./issues/04-split-profiles-features.md)   | Split profiles from features | `myNixOS.profiles.*` holds host classes and single-concern features under one name.                   |
| [05](./issues/05-deploy-staleness-metric.md)   | Deploy staleness metric     | `system.configurationRevision` is set but never exported. Nothing knows which hosts are behind.       |

## Decisions recorded as ADRs

- [ADR-0001](../../docs/adr/0001-host-roster-as-plain-nix-file.md) — why the roster is a plain file rather than a flake output
- [ADR-0002](../../docs/adr/0002-ci-detects-deploys-stay-manual.md) — why CI does not gate, and why deploys are still by hand
- [ADR-0003](../../docs/adr/0003-testing-strategy.md) — what is tested, what is deferred, and what a VM test cannot reach

## Rejected, deliberately

Recorded so they are not re-proposed. Reasoning is in ADR-0002 and ADR-0003.

- **deploy-rs** — revisit at the third VPS.
- **`system.autoUpgrade`** — unattended upgrades on unstable, ungated, turns one
  bad lock bump into five bad hosts.
- **A release channel for servers** — doubles the nixpkgs surface to solve a
  problem the CI gate solves better.
- **PR-based branch protection** — ceremony for a single-user forge where pushes
  are already tailnet-only.
- **Per-host VM smoke tests** — CI already builds every closure, and the systemd
  collector asserts unit health against the real hosts continuously.

## Drift found in passing

Not worth issues of their own.

- `hosts/README.md` says Helium is "Earmarked for Immich and Paperless".
  Paperless is enabled in `hosts/helium/default.nix`.
- `homes/server.nix` installs `jdk_headless` on all three servers for a
  Minecraft server that does not exist yet.
- All five hosts carry `system.stateVersion = "25.11"` though the repo begins
  2026-07. Harmless, and it must not be changed now — worth confirming it was
  deliberate rather than copied.
