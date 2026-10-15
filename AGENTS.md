# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Operating notes for coding agents working in this repository. Read
[CONTEXT.md](./CONTEXT.md) alongside this. It defines the vocabulary
(`myNixOS`, snippets, profiles, the host naming scheme) that the rest of the
tree and this file both assume.

## what this repository is

A flake-parts NixOS configuration for a five-host homelab. It builds five
`nixosConfigurations`, three of which are servers. Argon holds a git forge, a
password manager and an ATProto PDS, and Helium holds a document archive.

A bad change here is not a failing test. It is a service that stops
answering, or an archive that silently stops containing a database.

Nothing here is deployed by CI. Deploys are a person running `just update`.

## commands

```
just check                                   # nixfmt, statix, deadnix, shellcheck
nix flake check                              # all hosts + hooks + regressions
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
nix eval .#nixosConfigurations.<host>.config.<path>
nix build .#checks.x86_64-linux.<name>       # one regression
```

Hosts: `argon`, `carbon`, `helium`, `tungsten`, `uranium`. Check names:
`architecture`, `forgejo-runner-socket`, `pre-commit`, `restore-coverage`,
`restore-runner`.

## what you can and cannot do

You can evaluate and build. You cannot deploy, and you cannot read secrets.

- `nix eval .#nixosConfigurations.<host>.config.<path>` is the fastest way to
  check that an option exists and resolves. Use it before claiming an option
  path in a doc or a script. Checking a related option can miss generated
  settings, as the [GRUB review](#known-drift) showed.
- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` builds a
  host in full. This is the real check that a change works.
- `nix build .#braxton-is`, `.#tealfm-piper`, `.#tranquil-pds` build the
  packages defined in `modules/flake/packages.nix`.
- `nix flake check` evaluates every host, runs the pre-commit hook set over
  the whole tree, and runs the architecture, Forgejo runner socket and mocked
  restore regressions.
- `just check` runs the hook set alone (`nixfmt`, `statix`, `deadnix`,
  `shellcheck`), which is faster and catches almost everything you will break.

Do not run `nixos-rebuild`, `just update`, `just deploy-site`, or any `just
restore-*` recipe. The rebuild recipes switch a live system. The restore recipes
are interactive by construction, needing a YubiKey touch per decrypt and a sudo
prompt per host. Propose them, do not run them.

Do not run `agenix`. Every secret is encrypted to host root keys plus one
YubiKey, so decryption needs hardware that is not attached to the process you
are running in. Editing a `.age` file is a task for the user.

## how to change things

### adding an option or a service

Read the [module conventions](./modules/README.md#the-shape-of-a-module) before
editing modules. That guide owns module shape, automatic imports, `self`,
file references, option priorities and host-local disk layouts. Read the
[shared registry rules](./modules/README.md#snippets-hold-data-no-config) before
adding a service or changing its port.

Services bind loopback and Caddy is the route in. Follow the
[network policy](./CONTEXT.md#everything-binds-loopback-and-caddy-is-the-only-way-in)
when wiring a proxy or changing access controls.

### touching backups

`modules/nixos/services/backups` is the highest-consequence module in the tree
and has a [README of its own](./modules/nixos/services/backups/README.md). Read
it in full before editing. The mistake that has already been made once: an
exclude pattern covering borgmatic's dump staging path (`/run`, `/tmp`) drops
the database from every archive while everything still reports success.

## conventions the linters enforce

`just check` runs these, and `nix flake check` runs the same set, so they cannot
drift from each other:

| hook | what it catches here |
| --- | --- |
| `nixfmt` | RFC 166 formatting. Non-negotiable; the editors call it too. |
| `deadnix` | Unused module arguments. A module that stopped reading `osConfig` would otherwise keep taking it forever. |
| `statix` | Nix antipatterns. `repeated_keys` is disabled in `statix.toml` because it is wrong for NixOS option paths. |
| `shellcheck` | `--severity=warning` on the scripts and justfile recipes. |

The hooks install themselves through direnv (`use flake` in `.envrc`), so a
`cd` into the repo is the setup step.

## commit conventions

Conventional Commits, lowercase, with an optional scope naming the service or
module: `feat(piper): init`, `fix(pds): update tranquil to main branch`,
`chore: nix flake update`, `docs: correct stale paths`. Longer subjects in the
imperative mood also appear and are fine.

The author is `Braxton Fair <hello@taxborn.com>`. Commits written with agent
help carry a `Co-Authored-By` trailer.

Commit frequently with each substantive change, NEVER push without approval.

## comment style

Apply unslop to new and rewritten prose. Use periods or commas instead of em
dashes, and preserve technical reasoning when shortening comments. Existing
prose does not need a punctuation-only rewrite.

This repository comments heavily, and the comments are documentation rather
than noise. The house style is narrow: explain why the obvious thing is wrong
here. A comment that restates the code gets deleted. A comment recording that
`MemoryDenyWriteExecute` cannot be enabled because V8 executes the memory it
writes stays forever.

When you remove or rewrite code carrying one of these comments, the reasoning
either still applies, in which case carry it over, or it does not, in which case
say so in the commit message. Silently dropping one loses the only record of why
a thing was tried.

Match the density of the file you are in. `modules/nixos/services/backups` and
`modules/nixos/services/caddy.nix` are the reference for how much explanation a
security-relevant decision earns.

## invariants that must not be broken

The authoritative explanations live with their subject. Read the relevant one
before changing these settings:

- [Network policy](./CONTEXT.md#everything-binds-loopback-and-caddy-is-the-only-way-in)
  covers Cloudflare mTLS, mutually exclusive Caddy postures, `directVHosts`,
  forwarded client addresses and fail2ban tailnet exemptions.
- [Fleet agreement](./modules/README.md#fleet-agreement) covers build, tailnet
  and secret-rule rosters, plus the limits of recipient checks.
- [Secret operations](./secrets/README.md#working-with-them) covers the CLI's
  working directory, explicit identity and rekeying requirements.
- [Provisioning](./README.md#provisioning-a-new-host) orders installation,
  root-key collection, recipient registration and the first real rebuild.
- [Database backups](./modules/nixos/services/backups/README.md#databases)
  explains why live database files and dump staging exclusions lose data.

## known drift

Read the [2026-09-05 maintenance review](./docs/reviews/2026-09-05-maintenance.md)
before restoring removed settings or changing a retained one. It records the
OVH GRUB targets, opt-in bees deduplication, and the retired runner decision.
Its monitoring decision was reversed when the stack returned, see the
follow-up at the end. Its Mako and Hypridle entries describe the desktop that
Niri replaced.

## file map

See the [repository layout](./README.md#layout) and the
[module guide](./modules/README.md).
