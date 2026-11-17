# architecture

How the five hosts are assembled, and where to put a change.

## the hosts

Hosts are named after chemical elements. The name carries no meaning beyond
identity.

| host | machine | role |
| --- | --- | --- |
| argon | OVH VPS | server: most of `biscuits.at`, the PDS, the knot |
| carbon | OVH VPS | server: Tangled spindle, `braxton.is` |
| helium | Intel NUC at home | server: backup target, Paperless, monitoring |
| tungsten | Dell XPS 15 9520 | workstation (laptop) |
| uranium | desktop PC | workstation |

The homelab is not expected to grow, so the configuration has no machinery for
growth: no enable switches, no profiles, no auto-imported module trees. See
[decisions](./decisions.md#2026-11-simplification).

## layout

```
flake.nix              inputs, and `import-tree ./modules/flake` for outputs
homelab.nix            homelab-wide settings, plain data
modules/options.nix    types homelab.nix as `homelab.*`
modules/flake/         flake-parts: hosts, packages, checks, hooks, restore plan
modules/nixos/common/  every host: base system, user, nix, ssh, btrfs, swap,
                       tailscale, monitoring client, backup client
modules/nixos/server.nix        role: caddy and fail2ban
modules/nixos/workstation/      role: desktop, boot, YubiKey, containers
modules/nixos/ovh.nix           hardware shared by argon and carbon
modules/nixos/services/         one file per service, imported by its host
modules/home/          home-manager: default.nix for every host,
                       workstation.nix for workstations
modules/disko/         shared disk layouts
hosts/<host>/          default.nix, disko.nix, proxy.nix and host-only hardware
secrets/               agenix files and the secrets.nix rule file
keys/                  public keys: host roots, YubiKey, origin-pull cert
scripts/, tests/       operational bash and regression tests
docs/                  these guides
```

## how a host is built

`modules/flake/hosts.nix` builds one `nixosSystem` per name in
`homelab.hosts`. Every host gets:

- `hosts/<host>`
- the input modules (agenix, catppuccin, disko, home-manager, lanzaboote,
  piper, the knot and the spindle)
- `modules/nixos/common`
- `modules/options.nix`

The host file then imports what makes it different:

```nix
imports = [
  ../../modules/nixos/server.nix              # or ../../modules/nixos/workstation
  ../../modules/nixos/ovh.nix                 # shared hardware, if any
  ../../modules/nixos/services/vaultwarden.nix
  ./disko.nix
  ./proxy.nix
];
```

There are no enable switches. A module that is imported is on. To move a
service, move its import line to another host, then add that host to the
service's secret rules.

## homelab-wide settings

`homelab.nix` holds every value that more than one file needs: the host list
with tailnet addresses, domains and ports, the owner's identity, mail
settings, ntfy topics, the rsync.net account, the backup server and the
monitoring lists. It is plain Nix data because `secrets/secrets.nix` imports
it, and the agenix CLI evaluates that file outside the module system.

`modules/options.nix` declares the same tree as typed `homelab.*` options with
`homelab.nix` as their defaults, so modules read `config.homelab.services.atuin.port`.
Home-manager modules read `osConfig.homelab`. Ports are checked to be in
1–65535, and `sshDomain`/`sshPort` must be set together.

Modules that still need a knob declare it under the same namespace:
`homelab.caddy.*`, `homelab.backups.*`, `homelab.minecraft.servers`,
`homelab.ovh.ipv6`, `homelab.btrfs.*`, `homelab.ssh.openFirewall`,
`homelab.atuin.openRegistration`, and the read-only `homelab.tailscale.address`
and `bindOrdering`.

## conventions

- **Modules take `self`, never `inputs`.** `specialArgs` passes only `self`. A
  package built from an input is defined in `modules/flake/packages.nix` and
  reached as `self.packages.<system>.<name>`. An input's source tree, which is
  not a package, is read as `self.inputs.<name>` (manix does this).
- **Files are referenced by path.** In-repo files use `"${self}/keys/foo.pub"`
  or a relative path.
- **`mkDefault` for overridable shared settings** (locale, timezone, kernel),
  `mkForce` only where two modules conflict.
- **Services bind loopback, and Caddy is the way in.** See [network](./network.md).
- **Secrets never go in `settings`.** nixpkgs renders it into the
  world-readable store. Use an agenix environment file.
- **A service registers its own database dump** under `homelab.backups`. See
  [backups](./backups.md#databases).
- **Comments are for consequences.** A comment stays only where deleting the
  line would silently lose data or widen access. Everything else belongs in
  `docs/`.

## packages

`modules/flake/packages.nix` builds what nixpkgs does not provide at the right
version:

- **tranquil-pds** and its frontend come from the pinned `tranquil-src` input,
  overriding nixpkgs' derivations. The version is `0.8.0-unstable-<shortRev>`,
  because upstream has not bumped Cargo.toml and two commits would otherwise
  share a version. The frontend's `sourceRoot` is `source/frontend`, since a
  flake input has no `name`. `cargoDeps` and `pnpmDeps` are replaced outright.
  Their hashes are fixed-output derivations of the old source, so editing a
  hash does nothing. `fetchCargoVendor` is used because Tranquil pulls 13
  crates from git.
- **tealfm-piper** is built from the input's checkout with its own vendor hash,
  so a dependency change fails the build instead of passing silently.
- **spindle-nixos-image** is the guest the spindle boots for `image: nixos`.
- **catppuccin-lazygit** is imported from catppuccin/nix, which does not export
  it as a flake package.

The pinned inputs and how to upgrade them are in
[services](./services.md#pinned-services). tangled.org redirects fetches to a
knot host, which is worth knowing when a fetch fails in a way that looks like
DNS.

## checks and hooks

| command | what it runs |
| --- | --- |
| `just check` | nixfmt (RFC 166), deadnix, statix, shellcheck over the tree |
| `nix flake check` | every host's evaluation, the hooks, and the regressions below |
| pre-push hook | `nix flake check --no-build` |

The hook set is shared by `.git/hooks/pre-commit` and `checks.pre-commit`, so
the two cannot drift. deadnix catches modules that keep taking arguments they
no longer read. shellcheck runs at `--severity=warning`. statix runs over the
whole tree so it can read `statix.toml` (which disables `repeated_keys`), and
ignores `.direnv`, because otherwise it follows direnv's symlinks into the
store. `use flake` in `.envrc` installs the hooks on the first `cd`.

Regressions:

- `architecture` (`tests/architecture.nix`): the service registry's types, the
  per-secret recipient check, the spindle refusing the backup server, database
  dumps following their service paths, and the restore plan following
  repository settings.
- `restore-coverage` and `restore-runner`: the restore plan built from every
  host's repositories, and the restore scripts run against mocked commands.

Each host also asserts that every age secret it uses exists and names that host
and the YubiKey (`modules/nixos/common/fleet.nix`). That reads the rules, not
the encrypted files, so it cannot prove a file was rekeyed.

## theming

Catppuccin Mocha with the Mauve accent, set at the NixOS level and in the home
profile with `autoEnable = true`, so theming is opt-out. Glance's colours are
the same palette typed out as HSL.
