# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Operating notes for coding agents working in this repository. Read
[docs/architecture.md](./docs/architecture.md) alongside this. It explains how
hosts are assembled, `homelab.nix`, and the conventions the tree assumes.

## what this repository is

A flake-parts NixOS configuration for a five-host homelab: three servers
(Argon, Carbon, Helium) and two workstations (Tungsten, Uranium). Argon holds a
git forge, a password manager and an ATProto PDS, and Helium holds a document
archive and every host's second backup copy.

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
`architecture`, `pre-commit`, `restore-coverage`, `restore-runner`.

## what you can and cannot do

You can evaluate and build. You cannot deploy, and you cannot read secrets.

- `nix eval .#nixosConfigurations.<host>.config.<path>` is the fastest way to
  check that an option exists and resolves. Use it before claiming an option
  path in a doc or a script. Checking a related option can miss generated
  settings (see the GRUB entry in [decisions](./docs/decisions.md)).
- `nix build .#nixosConfigurations.<host>.config.system.build.toplevel` builds a
  host in full. This is the real check that a change works.
- `nix build .#tealfm-piper`, `.#tranquil-pds` build the packages defined in
  `modules/flake/packages.nix`.
- For a refactor, compare each host's `toplevel.drvPath` before and after. A
  change that should not alter behaviour should not alter the derivation
  beyond the flake's own source path and revision.

Do not run `nixos-rebuild`, `just update`, or any `just restore-*` recipe. The
rebuild recipes switch a live system. The restore recipes are interactive by
construction, needing a YubiKey touch per decrypt and a sudo prompt per host.
Propose them, do not run them.

Do not run `agenix`. Every secret is encrypted to host root keys plus one
YubiKey, so decryption needs hardware that is not attached to the process you
are running in. Editing a `.age` file is a task for the user.

## how to change things

- **A homelab-wide value** (a port, a domain, an address, an email) goes in
  `homelab.nix`, with its type in `modules/options.nix`. Modules read it from
  `config.homelab`, home-manager from `osConfig.homelab`. Never write a port
  literal into a vhost.
- **A new service** is a file in `modules/nixos/services/`, imported by the host
  that runs it, with its domain and port in `homelab.nix` and its vhost in that
  host's `proxy.nix`. Bind loopback. Put secrets in an agenix environment file,
  never in `settings`. Register any database dump under `homelab.backups`.
- **Something every host needs** goes in `modules/nixos/common`. Something every
  server or every workstation needs goes in `server.nix` or `workstation/`.
  Hardware only one host has goes in that host's directory.
- **Network or access changes** follow [network](./docs/network.md).
- **Backups.** `modules/nixos/services/backups` is the highest-consequence module
  in the tree. Read [docs/backups.md](./docs/backups.md) in full before editing
  it. The mistake that has already been made once: an exclude pattern covering
  borgmatic's dump staging path (`/run`, `/tmp`) drops the database from every
  archive while everything still reports success.

## conventions the linters enforce

| hook | what it catches here |
| --- | --- |
| `nixfmt` | RFC 166 formatting. The editors call it too. |
| `deadnix` | Unused module arguments. |
| `statix` | Nix antipatterns. `repeated_keys` is disabled in `statix.toml` because it is wrong for NixOS option paths. |
| `shellcheck` | `--severity=warning` on the scripts and justfile recipes. |

The hooks install themselves through direnv (`use flake` in `.envrc`), so a
`cd` into the repo is the setup step.

## commit conventions

Conventional Commits, lowercase, with an optional scope naming the service or
module: `feat(piper): init`, `fix(pds): update tranquil to main branch`,
`chore: nix flake update`, `docs: correct stale paths`. The body says what
changed and why, more than how.

The author is `Braxton Fair <hello@taxborn.com>`. Commits written with agent
help carry a `Co-Authored-By` trailer.

Commit frequently with each substantive change, NEVER push without approval.

## comment style

Keep comments to a minimum. A comment stays in a `.nix` file only where deleting
the line it explains would silently lose data or widen access, and then it is
one line. Everything else, the reasoning behind a setting, its history and the
traps around it, belongs in the matching page under `docs/`.

When you remove or rewrite code, its reasoning either still applies, in which
case it moves to `docs/`, or it does not, in which case say so in the commit
message.

Apply unslop to new and rewritten prose. Use periods or commas instead of em
dashes.

## invariants that must not be broken

Read the relevant page before changing these:

- [Network](./docs/network.md) covers Cloudflare mTLS, the mutually exclusive
  Caddy postures, `directVHosts`, forwarded client addresses and fail2ban's
  tailnet exemption.
- [Secrets](./docs/secrets.md#working-with-them) covers the CLI's working
  directory, explicit identity and rekeying requirements.
- [Provisioning](./README.md#provisioning-a-new-host) orders installation,
  root-key collection, recipient registration and the first real rebuild.
- [Database backups](./docs/backups.md#databases) explains why live database
  files and dump staging exclusions lose data.
- [Decisions](./docs/decisions.md) lists settings that look removable and are
  not.
