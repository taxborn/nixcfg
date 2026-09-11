# modules

Everything the hosts are assembled from. Four of these directories declare a
custom option namespace; the rest are plumbing.

| directory | namespace | evaluated in |
| --- | --- | --- |
| [`nixos/`](./nixos) | `myNixOS.*` | NixOS |
| [`home/`](./home) | `myHome.*` | home-manager |
| [`hardware/`](./hardware) | `myHardware.*` | NixOS |
| [`snippets/`](./snippets) | `mySnippets.*` | both |
| [`users/`](./users) | | NixOS |
| [`disko/`](./disko) | | NixOS, via `diskoConfigurations` |
| [`flake/`](./flake) | | flake-parts |

## how a module gets loaded

`flake/modules.nix` hands each of `nixos`, `home`,
`hardware`, `users`, and `snippets` to `import-tree`, which imports every `.nix`
file beneath it. Creating the file is the whole registration step. There is no
import list, and adding one would break the pattern rather than tidy it.

So the directory structure is organisational only. Nesting says nothing about
the option path. `nixos/services/forgejo/default.nix` declares
`myNixOS.services.forgejo` because it says so, not because of where it sits.
Keep the two aligned anyway; every file in here does.

`disko/` and `flake/` are the exceptions. `flake/modules.nix` exports reusable
disk layouts; `hosts/<host>/disko.nix` selects a layout and supplies its `by-id`
drive paths. Helium's single-host layout lives there in full. `flake/` is itself
the `import-tree` target of `flake.nix`.

Each host declares `nixpkgs.hostPlatform` in its own `default.nix`. CPU-vendor
modules configure drivers and firmware, not the architecture.

## the shape of a module

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

A module aliases its own subtree as `cfg`. System, home and hardware modules
take `self`, never `inputs`, because `flake/hosts.nix` passes only the former in
`specialArgs`. A package a module needs gets re-exported through
`flake/packages.nix` rather than reached for directly. In-repo files are
`"${self}/keys/foo.pub"`, not relative paths.

Use `lib.mkDefault` for shared settings a host may override, such as locale,
timezone or boot-loader choices. Reserve `lib.mkForce` for conflicting modules
where one must win, such as lanzaboote disabling systemd-boot.

Option descriptions carry the reasoning. See the comment style section of
[AGENTS.md](../AGENTS.md#comment-style) for what that means in practice.

## the sub-namespaces

- `profiles/` bundles other `enable`s, keyed on role (`server`, `workstation`)
  or on a subsystem every host wants a coherent answer for (`btrfs`, `swap`,
  `audio`). A host picks one and names its exceptions. Both role profiles enable
  `base`, so anything true of every machine goes there.
- `programs/` configures a single program.
- `services/` is a daemon, usually with a `networkMap` entry, an agenix secret,
  and a Caddy vhost in the host's `proxy.nix`.

## snippets hold data, no config

A file under `snippets/` declares options and sets no config. It is a registry,
imported into both the NixOS and the home-manager module sets so that two sides
of the same fact cannot drift:

- `mySnippets.biscuits-at.networkMap` holds domain, port, and SSH details per
  service. The Forgejo module and the SSH client config read the same port from
  here. Entries require a nonempty `domain` and a `port` from 1 through 65535.
  SSH entries require both `sshDomain` and `sshPort`. Unknown fields fail
  evaluation. Add a service here and read the entry from both its module and
  proxy; never write a port literal into a Caddy vhost.
- `mySnippets.tailnet` holds the tailnet name and the hostname to Tailscale IP
  map. Backups use it to address the backup server, and fleet assertions
  require its names to match the build roster.
- `mySnippets.ssh.knownHosts` pins host keys, assembled from `../keys` and the
  tailnet map.

The old `alwaysOn` and `physicalDisks` options had no readers after monitoring
went in `f4012fc`, so they were removed. If monitoring returns, preserve the
reasoning before choosing its data model. Only Argon, Carbon and Helium should
alert on absence. An offline workstation is normal. SMART monitoring belongs
on Helium, Tungsten and Uranium, since the OVH guests expose virtual disks.
Exporter enablement and scrape targets must agree, and the OVH hardware profile
already disables `smartd` for the same reason.

## fleet agreement

The build roster in `flake/hosts.nix`, the tailnet map and the per-host borg
rules in `secrets/secrets.nix` must contain the same names. `nixos/fleet.nix`
asserts this on every host. It also checks that shared tailnet secret rules
include every host and the recovery YubiKey, and that each configured age file
exists with a rule naming its consuming host and the YubiKey.

These checks inspect rules and public keys. They cannot prove that an encrypted
file was rekeyed after its rule changed. Follow the [secrets procedure](../secrets/README.md#working-with-them)
and run the [key recovery test](./nixos/services/backups/README.md#tier-0-key-material)
after changing recipients.

`nix eval --json .#restoreCoverage` lists every enabled backup client and each
repository's restore coverage. `flake/restore.nix` derives this plan from the
host configurations. See the [restore procedure](./nixos/services/backups/README.md#testing-restore)
for local repository omissions and workstation rehearsals.

## modules with their own README

- [`home/desktop/niri/`](./home/desktop/niri/README.md) covers the minimal
  Niri and Noctalia workstation session and its shortcuts.
- [`nixos/services/backups/`](./nixos/services/backups/README.md) covers borg
  and borgmatic, provisioning a host into the backup set, and the three tiers of
  restore testing. It is the highest-consequence module here. Read it in full
  before editing.

## retired runner

The replacement [Forgejo runner](./nixos/services/forgejo-runner/README.md)
runs on Carbon with rootless Podman and v16 registration. It does not share a
Nix store between jobs. The notes below describe the earlier setup.

The Forgejo runner module went in `f4012fc`. The old `just runner-gc` recipe
queried its missing `storeVolume` and `nixImage` options, so it could not run.
Do not restore the recipe without restoring a runner configuration.

A runner that shares `/nix` between containers needs a deliberate GC procedure.
Nix names temporary roots after process IDs. Separate PID namespaces can reuse
the same IDs, so one container can remove another build's roots and let GC
delete paths that build still uses. Stop the runner and wait for active jobs
before collecting the shared store. Shutdown can take `shutdown_timeout`.
Restart the runner even if collection fails.

The retired setup used rootless Podman as `forgejo-runner`. Its commands needed
that user's `XDG_RUNTIME_DIR`, `/run/user/<uid>`, and lingering kept the runtime
directory available between logins. Recover the exact procedure from history
only after checking the replacement runner's user, image and volume.
