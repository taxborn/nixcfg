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
  path in a doc or a script; several already in the tree do not exist (see
  [known drift](#known-drift)).
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

Verified against the tree as of this writing. Do not propagate these into new
code or docs, do not "fix" one by inventing the option it is missing, and do
not read an inert setting as evidence that the thing it names exists:

- `just runner-gc` evaluates
  `myNixOS.services.forgejo.runner.{storeVolume,nixImage}`. The Forgejo runner
  module was deleted in `f4012fc`; the recipe is dead and fails at `nix eval`.
  It is kept on purpose and says so in its own comment: the pid-namespace
  reasoning it carries is the expensive part, and a runner coming back would
  need it.
- `mySnippets.tailnet.alwaysOn` and `.physicalDisks` are read by nothing. The
  monitoring module that read them went in `f4012fc`. Their descriptions say
  that now, rather than describing a Prometheus server this repo does not have,
  but the options themselves are still inert.
- `modules/nixos/services/braxton-is.nix` defaults `port = 3003`, the same port
  the PDS takes in `networkMap`. Harmless only while the two run on separate
  hosts.
- `modules/hardware/intel/cpu.nix` sets `nixpkgs.hostPlatform`, and nothing
  else in the tree does. Every host's platform therefore depends on a
  CPU-vendor module being enabled. All five enable it, so this holds only by
  coincidence; a host with an AMD CPU would evaluate with no platform at all.
- `modules/hardware/nvidia/gpu.nix` gates the i915 initrd module on
  `myHardware.intel.cpu.enable`, while the comment above it explains the
  ordering in terms of hybrid Intel+Nvidia *graphics*. Those are different
  properties: uranium pairs an Intel CPU with an AMD GPU and no nvidia.
- `modules/nixos/services/fail2ban.nix` sets `bantime-increment.overalljails`,
  which has nothing to escalate across. `f4012fc` deleted the caddy-auth,
  vaultwarden and forgejo jails, leaving sshd as the only jail declared here.
- `modules/disko/btrfs-ovh.nix` declares a 2M EF02 BIOS-boot partition, but
  `modules/nixos/programs/grub.nix` installs in EFI mode and no host sets
  `boot.loader.grub.device`, so nothing ever writes BIOS-mode GRUB into it.
- `modules/nixos/profiles/btrfs.nix` builds `btrfsFSDevices` with a
  `mountPoint` field nothing downstream reads, and no host enables
  `deduplicate`, so the whole beesd path is unexercised.
- `modules/nixos/services/glance.nix` links to `https://i.biscuits.at`, an
  Immich instance that has no module anywhere in this repo.
- `homes/server.nix` installs `jdk_headless`, and `modules/home/services/mako.nix`
  installs `mpv` and puts it on the unit's PATH. Nothing in the tree invokes
  either; the mpv pair looks like the remains of a notification-sound setup.
- `modules/home/services/mako.nix` and `modules/home/services/hypridle.nix`
  hand-write systemd units (`Type = "dbus"` with `BusName`,
  `Restart = mkForce "no"`, `BindsTo` on `hyprland-session.target`) that
  override what home-manager generates. `882efdc` introduced them recording no
  reason, and none has been reconstructed since.
- Uranium and Tungsten carry no comments, which was deliberate: `50743d4` and
  `83016a3`, both "docs: clean up excessive comments", removed the reasoning
  for `aesni_intel` in the initrd and for `cpu-epp` over
  `powerManagement.cpuFreqGovernor`. Both of those fail silently rather than
  loudly, so the reasoning is worth rewriting if anyone reconstructs it.

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
