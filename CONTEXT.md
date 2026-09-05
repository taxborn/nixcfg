# CONTEXT.md

The vocabulary and the recurring practices in this repository: the things that
are obvious once you have read the whole tree and confusing until then. This is
a glossary, not a tutorial. [AGENTS.md](./AGENTS.md) covers how to work in here,
and the per-directory READMEs cover their own subjects in depth.

## naming

### hosts are chemical elements

`argon`, `carbon`, `helium`, `tungsten`, `uranium`. The name carries no meaning
beyond identity; role is a property of the config. Roughly:

| host | what it is | role |
| --- | --- | --- |
| argon | OVH VPS | server, most of `biscuits.at` |
| carbon | OVH VPS | server, `braxton.is` |
| helium | Intel NUC at home | server, backup target, Paperless |
| tungsten | Dell XPS 15 9520 | workstation (laptop) |
| uranium | desktop PC | workstation |

The roster appears in exactly three places, and all three have to agree:
`modules/flake/hosts.nix` (what gets built), `secrets/secrets.nix` (who can
decrypt what), and `mySnippets.tailnet.tailscaleIPs` (who is on the tailnet and
therefore who gets backed up).

### domains

- `biscuits.at` is the homelab's service domain. Everything in
  `mySnippets.biscuits-at.networkMap` lives under it.
- `braxton.is` is the personal website, served from Carbon out of a separate
  repository pinned as a flake input.
- `taxborn.com` is the identity. `hello@taxborn.com` is the actual mailbox and
  the Fastmail login; `infra@biscuits.at` is a *sending identity* that services
  use as their `From`. Every service that sends mail relays through Fastmail on
  port 465 (implicit TLS, not STARTTLS) with that pair. SPF and DKIM records sit
  at the `biscuits.at` apex and do not descend to subdomains, so sending as
  anything under one means unauthenticated mail.

## the option namespaces

Four custom namespaces, distinguished by which evaluation they belong to:

| namespace | evaluated in | declared under |
| --- | --- | --- |
| `myNixOS.*` | NixOS | `modules/nixos/` |
| `myHome.*` | home-manager | `modules/home/` |
| `myHardware.*` | NixOS | `modules/hardware/` |
| `mySnippets.*` | both | `modules/snippets/` |

Everything is one flat, mostly-boolean set of options. A host file says
`myNixOS.services.forgejo.enable = true` and the module does the rest, so a host
file reads as a list of decisions rather than as configuration.

### snippet

A module under `modules/snippets/` that declares options and sets no config. It
is pure data, a registry, imported into both the NixOS and the home-manager
module sets. That is the point: the SSH client config in
`modules/home/programs/ssh.nix` and the Forgejo server config in
`modules/nixos/services/forgejo/default.nix` read the same port out of the same
attribute, so they cannot disagree.

Three exist:

- `mySnippets.biscuits-at.networkMap` holds domain, port, and where relevant SSH
  details for each service. It is the single source of truth for what runs where
  on what port. Never write a port literal into a Caddy vhost; read it from
  here.
- `mySnippets.tailnet` holds the tailnet name and the hostname to Tailscale IP
  map, which doubles as the fleet roster.
- `mySnippets.ssh.knownHosts` pins host keys, built from `keys/` and the tailnet
  map.

### profile

A module whose config is mostly a bundle of other `enable`s. `profiles.server`
turns on `base`, Caddy, and fail2ban; `profiles.workstation` turns on `base`,
audio, bluetooth, containers, graphical boot, and a desktop's worth of services.
A host picks one and then names its exceptions.

Profiles compose downward. Both server and workstation enable `base`, so
anything true of every machine goes there.

The same word appears in `myHardware.profiles.*` (`laptop`, `ovh`), meaning the
same thing one layer down, a bundle keyed on chassis rather than role.

## module conventions

### `import-tree`, so there is no import list

`modules/flake/modules.nix` hands each directory to `import-tree`. Every `.nix`
file under `modules/nixos/`, `modules/home/`, `modules/hardware/`,
`modules/users/`, and `modules/snippets/` is imported automatically. Creating
the file *is* the registration. The directory structure is organisational only
and carries no semantics beyond which namespace the file should declare into.

### `self`, never `inputs`

Modules receive `self` in `specialArgs` and nothing else from the flake. In-repo
files are referenced as `"${self}/keys/root_argon.pub"`. When a module needs a
package built from an input, that package is re-exported through
`modules/flake/packages.nix` and reached as
`self.packages.${pkgs.stdenv.hostPlatform.system}.<name>`. That also means
`nix build .#<name>` works from this repo, which is the smoke test before a
deploy.

### `cfg`

Every module aliases its own option subtree as `cfg` in a `let`, and reads
`cfg.foo` in the body. Consistent enough that deviating reads as a mistake.

### `mkDefault` on anything a host might override

Options a host is expected to disagree with are set `lib.mkDefault` in the
shared module: locale, timezone, kernel packages, boot loader details. `mkForce`
appears only where two modules genuinely conflict and one has to win, for
example lanzaboote forcing `systemd-boot.enable = false`.

## practices

### the flake.lock revision *is* the deploy

Two services are deployed by moving a flake input rather than by copying files:

- `braxton-is`, where `just deploy-site` is `nix flake update braxton-is`, a
  commit, and a rebuild. Rolling the site back is rolling back a generation.
- `tranquil-src`, where `nix flake update tranquil-src` is the PDS upgrade.

The two are not symmetric, which is the part to remember. Rolling back the site
is free. Rolling back the PDS does not undo database migrations, so take a dump
first.

### comments that carry reasoning

Long comments in this tree are not decoration. They record a thing that was
tried, or a default that looks safe and is not. The recurring shape is: the
obvious change here is wrong, and here is the failure it produces.

Four worth reading:

- `MemoryDenyWriteExecute = false` in `braxton-is.nix`. V8 executes the memory
  it writes, so the hardening option that looks free makes Node abort.
- The PostgreSQL dump's exact `{ name; username; }` shape in the backups module.
  That precise combination is what makes nixpkgs relax the hardened unit.
- `PAPERLESS_OCR_LANGUAGE` deliberately unset in `paperless.nix`. Spelling out
  the default triggers a local rebuild of tesseract.
- The `grep -q` and SIGPIPE trap in the restore test, which inverted an
  assertion and reported a present database dump as missing.

### the "do not" list

The root [README.md](./README.md) ends with a list of decisions that are cheap
to forget and expensive to redo, mostly Tungsten BIOS attributes whose obvious
setting locks the machine out of its own root filesystem, plus two features
(hibernation, fingerprint) that were investigated and rejected. Treat it as
append-only. The alternative to writing an entry there is rediscovering it the
hard way.

### everything binds loopback, and Caddy is the only way in

No service module opens a firewall port. Services listen on `127.0.0.1` and
Caddy reverse-proxies them. Two mutually exclusive postures decide what reaches
Caddy:

- `cloudflareOnly` firewalls 80/443 to Cloudflare's published IP ranges, *and*
  requires every vhost to present a client certificate from Cloudflare's
  origin-pull CA (the `cloudflare-mtls` snippet). The allowlist proves a request
  came from Cloudflare's network, which anyone with an account can arrange; the
  certificate proves it came from this zone. An assertion makes forgetting the
  import a build failure.
- `tailnetOnly` does not open 80/443 at all. Caddy is reachable over the
  tailnet, whose interface is already trusted, and nowhere else. It costs the
  host HTTP-01, so every vhost has to solve DNS-01.

`directVHosts` is the way around that, and it is expensive: naming one vhost
reopens 80/443 to everyone for the whole host, because iptables cannot tell
which name a connection is about to ask for. The PDS is the case it exists for.

The `client-ip` snippet is the other half. Caddy appends to `X-Forwarded-For`
rather than replacing it and never sends `X-Real-IP`, so without it every
backend resolves Cloudflare's edge as the client.

### port allocation

Services on `biscuits.at` take a port from the `300x` sequence, recorded in
`networkMap`: 3000 glance, 3001 vaultwarden, 3002 forgejo, 3003 pds, 3004
paperless, 3005 piper. `braxton-is` stays out of the map because it is on a
different domain. It reserves port 3006 so it can share a host with the PDS.

### secrets are agenix, and the YubiKey is a recipient of everything

`.age` files under `secrets/`, with `secrets/secrets.nix` as the rule file
mapping each path to the keys that may decrypt it. Two tiers:

- `keys` covers every host root key plus the YubiKey, for anything any host
  might need.
- `hostKey <host>` covers one host's root key plus the YubiKey, for everything
  else.

The YubiKey is on both lists deliberately. If a host is gone, that key is the
only thing left that can open its archives.

A `.pub` sitting unencrypted beside a `.age` is intentional. Public halves are
not secret, and the config reads them straight out of the repo (Helium's
`authorizedKeys`, Forgejo's SSH signing key).

Two things bite every time. `agenix` must be run from `secrets/`, because it
resolves its argument as a rule name verbatim. And `agenix -d` needs `-i` with
the YubiKey identity, because `age.identityPaths` is a system-level setting that
the CLI never sees.

### backups, and the restore tiers

Every host writes each archive to two repositories, rsync.net off-site and
Helium's external drive over the tailnet, through borgmatic, one configuration
per repository.

The canary is `/var/lib/backup-canary`, a timestamp written into the backup set
so a restore has something to compare byte-for-byte. The byte comparison is the
assertion, never borg's exit code: an `--path` matching nothing still exits 0.

Restores are tested in three tiers, cheapest first, each proving something the
one below it does not:

- tier 0 (`just restore-keys`) proves the YubiKey can decrypt every host's borg
  passphrase and key. Seconds to run, and the highest-value check in the list,
  because it is the only thing left if a host is destroyed.
- tier 1 (`just restore-test <host>`) is a canary round-trip through every
  repository configured on that host, plus an assertion that database dumps are
  really in the archive.
- tier 2 (`just restore-dr <host> [repos]`) restores from a machine holding none
  of the host's material, using only the YubiKey.

A host running a database excludes the live files and puts a logical dump in the
archive instead. Copying a running database's files gives you a torn mix of
pages that will usually restore fine, which is exactly why it is not worth
relying on.

### theming

Catppuccin Mocha with the Mauve accent, set once at the NixOS level and once in
the home profile with `autoEnable = true`, so per-application theming is opt-out
rather than opt-in. Glance's HSL values in `glance.nix` are the same palette
written by hand, because that module takes raw colours.

### provisioning

Disk layouts are declarative (`modules/disko/`), parameterised by drive `by-id`
paths and instantiated per host in `modules/flake/modules.nix`. A new host is
installed with `nixos-anywhere` against a generic config, then given secrets,
then rebuilt properly. That ordering is not optional. agenix activation fails on
a missing `.age` file, so a host that is not yet a recipient cannot boot its own
services.

Workstations use LUKS on mdraid RAID1, unlocked by a FIDO2 YubiKey, under
lanzaboote-signed Secure Boot. That combination is why the BIOS "do not" list
exists.
