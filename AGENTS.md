# AGENTS.md

Operating notes for coding agents working in this repository. Read
[CONTEXT.md](./CONTEXT.md) alongside this. It defines the vocabulary
(`myNixOS`, snippets, profiles, the host naming scheme) that the rest of the
tree and this file both assume.

## what this repository is

A flake-parts NixOS configuration for a five-host homelab. It builds five
`nixosConfigurations`, three of which are internet-facing servers running real
services with real state: a git forge, a password manager, a document archive,
an ATProto PDS. A bad change here is not a failing test. It is a service that
stops answering, or an archive that silently stops containing a database.

Nothing here is deployed by CI. Deploys are a person running `just update`.

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
- `nix flake check` evaluates every host and runs the pre-commit hook set over
  the whole tree.
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

Each host declares `nixpkgs.hostPlatform` in its own `default.nix`. CPU-vendor
modules configure drivers and firmware, not the host architecture.

Every module in this tree has the same shape, and matching it matters more than
any individual preference:

```nix
{ config, lib, ... }:
let
  cfg = config.myNixOS.services.foo;
in
{
  options.myNixOS.services.foo.enable = lib.mkEnableOption "what this is";

  config = lib.mkIf cfg.enable {
    # ...
  };
}
```

- `import-tree` picks up files under `modules/nixos`, `modules/home`,
  `modules/hardware`, `modules/users`, and `modules/snippets` automatically (see
  `modules/flake/modules.nix`). Creating the file is the whole registration
  step. There is no list to add it to, and adding one is the wrong instinct.
- The only lists that do exist are the host roster in
  `modules/flake/hosts.nix` and the one in `secrets/secrets.nix`. A new host
  goes in both.
- Modules take `self`, never `inputs`. `modules/flake/hosts.nix` passes only
  `self` in `specialArgs`, and anything a module needs out of an input is
  re-exported through `modules/flake/packages.nix` to keep that true. Do not
  widen the argument set for one service.
- Reference in-repo files as `"${self}/keys/foo.pub"`, not by relative path.
- Option descriptions in this repo carry the reasoning, not a restatement of
  the name. If the answer to "why is this not the obvious thing?" is
  interesting, it belongs in the description.

### wiring a service to the network

Ports and hostnames for the `biscuits.at` services live in one place:
`mySnippets.biscuits-at.networkMap`. Add an entry there and read it from both
the service module and the Caddy vhost, so the two cannot drift. Do not write a
port literal into a vhost.

Services bind loopback. Caddy is the only route in. Nothing opens a firewall
port of its own.

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

Assertions or structure enforce these. Breaking one is either a build failure
or, worse, a silent hole:

- **Every vhost on a `cloudflareOnly` host imports `cloudflare-mtls`.** The IP
  allowlist proves a request came from Cloudflare's network, which anyone with
  an account can arrange; the client certificate proves it came from *this*
  zone. `modules/nixos/services/caddy.nix` asserts it. Listing a vhost in
  `directVHosts` to silence the assertion reopens 80/443 to the whole internet
  for the entire host.
- **`cloudflareOnly` and `tailnetOnly` are mutually exclusive**, and asserted
  to be.
- **fail2ban's `ignoreIP` must cover every address in
  `mySnippets.tailnet.tailscaleIPs`.** fail2ban hooks its chains ahead of the
  firewall's accept for trusted interfaces, so a ban landing on a tailnet
  address takes out the path used to lift it.
  `modules/nixos/services/fail2ban.nix` asserts it, and IPv6 addresses fall
  through as uncovered rather than being waved past.
- **`mySnippets.tailnet.tailscaleIPs` is the fleet roster.** Backups address
  the backup server through it. A host missing from it is not backed up.
- **Secrets exist before the host that reads them rebuilds.** agenix activation
  fails on a missing `.age` file, which means a new host's ordering is: install,
  collect its root host key into `keys/`, add it to `secrets/secrets.nix`,
  `agenix -r`, then rebuild.
- **`age.identityPaths` is system-level and does not reach the `agenix` CLI.**
  Anything decrypting by hand passes `-i` explicitly.
- **`agenix` must be run from `secrets/`.** It resolves its file argument as a
  rule name verbatim, so from the repo root no rule matches.

## known drift

Reviewed on 2026-09-05. The fixes and decisions are recorded in the root
[maintenance review](./README.md#maintenance-review). Do not reintroduce the
removed settings from older commits. These retained cases are easy to misread:

- The OVH EF02 partition is used. Disko derives
  `boot.loader.grub.devices = [ "/dev/sda" ]` from it. NixOS installs BIOS
  GRUB to that disk as well as EFI GRUB to the ESP. Checking only the singular
  `boot.loader.grub.device` misses the generated install target.
- Pinned home-manager configures Mako and registers its D-Bus package, but
  creates no systemd unit. The local unit starts it with Hyprland, waits for
  its bus name and stops it with the session. Hypridle does have an upstream
  unit and uses `services.hypridle.systemdTarget` in the home configuration.
- No host enables btrfs `deduplicate`. Its enabled branch was evaluated on
  Uranium and creates one bees daemon per distinct filesystem, each with a
  2 GiB hash table. Keep it opt-in until duplicate data justifies that cost.
- The retired runner's GC and monitoring distinctions live in
  [modules/README.md](./modules/README.md). There is no runnable `runner-gc`
  recipe or configurable monitoring roster without their consumers.

## file map

| path | what lives there |
| --- | --- |
| `flake.nix` | inputs only; outputs are `import-tree ./modules/flake` |
| `modules/flake/` | flake-parts modules: host roster, module exports, packages, hooks |
| `modules/nixos/` | `myNixOS.*` system options |
| `modules/home/` | `myHome.*` home-manager options |
| `modules/hardware/` | `myHardware.*` CPU/GPU/chassis options |
| `modules/snippets/` | `mySnippets.*` data, no config; imported into both NixOS and home |
| `modules/disko/` | disk layouts, parameterised and instantiated in `modules/flake/modules.nix` |
| `modules/users/` | the `taxborn` account |
| `homes/` | home-manager profiles (`default`, `server`, `workstation`) |
| `hosts/<host>/` | per-host config; `proxy.nix` beside it where the host runs Caddy |
| `secrets/` | agenix `.age` files and the `secrets.nix` rule file |
| `keys/` | public keys: host roots, YubiKey, PGP, the Cloudflare origin-pull cert |
| `scripts/` | operational bash invoked by justfile recipes |
