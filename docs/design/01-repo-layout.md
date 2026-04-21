# 01 - repo layout

## the three repos

The infrastructure is split across three git repos, all hosted on
`git.mischief.town`:

- **nixcfg** (this repo) - flake, modules, host configs. Public.
- **snippets** - reusable config fragments (`mySnippets.*` namespace),
  pulled in as a flake input. Public. Holds things like the
  `mischief-town.networkMap` (port/vhost source of truth) and shared
  nix settings.
- **secrets** - agenix-encrypted secrets, pulled in as a non-flake input.
  Private. Contains `.age` files and `secrets.nix` mapping keys to hosts.

The split exists so `nixcfg` can stay public without leaking secrets,
and so snippets can be consumed by ad-hoc tooling outside the flake.

## flake structure

`flake.nix` is minimal and delegates everything to `modules/flake/` via
flake-parts. This keeps the entry point stable and makes individual
concerns (nixos, home-manager) independently editable.

- `modules/flake/nixos.nix` enumerates hosts and wires up shared
  nixos modules, home-manager integration, and overlays.
- `modules/flake/home-manager.nix` exports `homeModules` for reuse.

Hosts are listed explicitly in `nixosConfigurations` rather than
globbed from disk. This is deliberate: adding a host should be a
conscious act that shows up in code review.

## module namespaces

Two top-level namespaces guard against collision with upstream options
and make intent obvious at call sites:

- `myNixOS.*` - system-level options (base, desktop, programs, services,
  profiles, hardware). Defined under `modules/nixos/` and `modules/hardware/`.
- `myHome.*` - home-manager options (desktop, programs, services, profiles).
  Defined under `modules/home/`.

A third namespace, `mySnippets.*`, comes from the snippets flake input
and is treated as read-only shared library.

## inputs

- `nixpkgs` - unstable. Deliberate: I track the latest and accept the
  churn in exchange for newer packages.
- `home-manager` - master, follows nixpkgs. Same reasoning.
- `disko` - declarative disk layout per host, lives under `modules/disko/`.
- `agenix` - secrets. Marked with a TODO to evaluate ragenix.
- `lanzaboote` - secure boot on workstations.
- `copyparty` - overlay + nixos module, consumed by helium-01.
- `tangled` - source of tangled-knot for carbon.
- `snippets`, `secrets` - see above.

All inputs that touch nixpkgs use `inputs.nixpkgs.follows = "nixpkgs"`
to keep the closure deduplicated.
