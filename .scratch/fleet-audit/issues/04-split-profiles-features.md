# Split host classes from features

Status: ready-for-agent

Blocked by: 03

## Problem

`myNixOS.profiles.*` holds two different kinds of thing.

**Host classes** — `server`, `workstation`. They enable other modules and define
what a host *is*. A host picks exactly one.

**Features** — `audio`, `bluetooth`, `btrfs`, `swap`, `containers`,
`graphical-boot`. Single-concern config, switched on *by* a class.

They landed in the same namespace because they are neither a `service` nor a
`program`, and `profiles/` was the nearest drawer. The result is that "which
profiles does this host have" cannot be answered by reading the profile list —
`workstation.nix` enables four of them, `base.nix` enables two more, and two of
those six are the classes themselves.

## Shape

Rename, no behaviour change.

- `myNixOS.profiles.{server,workstation}` stay where they are.
- The six features move to `modules/nixos/features/` under `myNixOS.features.*`.

Call sites to update: `base.nix` (`btrfs`, `swap`), `profiles/workstation.nix`
(`audio`, `bluetooth`, `btrfs.guiTools`, `containers`, `graphical-boot`),
`hosts/uranium/default.nix` (`profiles.btrfs.snapshotSubvolumes.compatdata`),
`hosts/helium/default.nix`, and anything else `rg 'myNixOS\.profiles\.'` turns
up.

## Sequencing

After [03](./03-host-roster.md). Both are wide diffs and they overlap in
`base.nix` and the host files; interleaved they will collide for no reason.

Do it with CI already green, so the rename is verified against all five closures
rather than against whichever host gets rebuilt first.

## Also fix, while here

`homes/workstation.nix` imports `./default.nix`, but `homes/server.nix` does
not — it is purely additive, relying on `base.nix` having already pulled in
`profile-default` for every host. Both work (the module system dedupes imports
by path), but two profiles built two ways is how they drift. Make
`workstation.nix` additive to match.

`homes/` itself stays where it is. `homeModules.profile-*` already names the
relationship clearly and moving it is churn.

## Done when

`myNixOS.profiles` has exactly two members, and every host's class is one line.
