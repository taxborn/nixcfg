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

The [fleet checks](./modules/README.md#fleet-agreement) keep the build roster,
tailnet map and secret rules in agreement. Host details live in
[hosts/](./hosts/README.md).

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

`myNixOS` configures the system, `myHome` configures home-manager, and
`myHardware` configures hardware. `mySnippets` is data shared by system and
home evaluations. See [modules](./modules/README.md) for the namespace table,
module shape, import rules and use of `self`.

### snippet

A snippet declares data without setting configuration. Service modules, Caddy
and SSH clients read the same registry rather than copying ports or hostnames.
The [snippet registry](./modules/README.md#snippets-hold-data-no-config) describes
the three namespaces and their consumers.

### profile

A profile bundles other modules by role or subsystem. A host enables
`profiles.server` or `profiles.workstation`, then names its exceptions. Both
include `base`. Hardware profiles use the same pattern for chassis, such as
`myHardware.profiles.laptop` and `myHardware.profiles.ovh`.

## practices

### the flake.lock revision *is* the deploy

Three services are deployed by moving a flake input rather than by copying files:

- `braxton-is`, where `just deploy-site` is `nix flake update braxton-is`, a
  commit, and a rebuild. Rolling the site back is rolling back a generation.
- `tranquil-src`, where `nix flake update tranquil-src` is the PDS upgrade.
- `tealfm-piper`, where `nix flake update tealfm-piper` is the Piper upgrade.
  It tracks upstream's default branch, so every update takes whatever landed.

The site is the odd one out, which is the part to remember. Rolling back the
site is free. Rolling back the PDS does not undo database migrations. Piper's
`db/db.go` alters its SQLite schema on startup with `ALTER TABLE ... ADD COLUMN`
and `CREATE TABLE IF NOT EXISTS`, and a rollback does not undo that either. Take
a dump first for both. `borgmatic create` takes one for Piper and the PDS on
Argon.

### comments that carry reasoning

The [comment policy](./AGENTS.md#comment-style) explains what belongs beside
code and what must survive a refactor. The backup module's dump staging and
PostgreSQL unit comments are examples of reasoning that prevents data loss.

### the "do not" list

The root [README.md](./README.md) ends with a list of decisions that are cheap
to forget and expensive to redo, mostly Tungsten BIOS attributes whose obvious
setting locks the machine out of its own root filesystem, plus two features
(hibernation, fingerprint) that were investigated and rejected. Treat it as
append-only. A decision that never gets an entry has to be rediscovered.

### everything binds loopback, and Caddy is the only way in

No service module opens a firewall port unless the host opts in, and the only
one that offers it is Minecraft, which Caddy cannot front. Services listen on `127.0.0.1` and
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
Argon also lists Forgejo's tailnet name, whose vhost has no mTLS and instead
aborts any peer outside the tailnet ranges.

The `client-ip` snippet is the other half. Caddy appends to `X-Forwarded-For`
rather than replacing it and never sends `X-Real-IP`, so without it every
backend resolves Cloudflare's edge as the client.

fail2ban's `ignoreIP` must cover every address in
`mySnippets.tailnet.tailscaleIPs`. fail2ban hooks its chains ahead of the
firewall's accept for trusted interfaces, so banning a tailnet address removes
the path used to lift the ban. The [fail2ban module](./modules/nixos/services/fail2ban.nix)
asserts coverage; it rejects uncovered IPv6 addresses too.

### port allocation

Services on `biscuits.at` take a port from the `300x` sequence, recorded in
`networkMap`: 3000 glance, 3001 vaultwarden, 3002 forgejo, 3003 pds, 3004
paperless, 3005 piper, 3007 ntfy, 3008 atuin, 3009 grafana. `braxton-is` stays out of the map because it is on a
different domain. It reserves port 3006 so it can share a host with the PDS.

### secrets and recovery

The [secrets guide](./secrets/README.md) owns recipient rules, the YubiKey
recovery identity and agenix commands. The [backup guide](./modules/nixos/services/backups/README.md)
owns repository setup, logical database dumps and the three restore tiers.
Read those procedures before working on either subsystem.

### theming

Catppuccin Mocha with the Mauve accent, set once at the NixOS level and once in
the home profile with `autoEnable = true`, so per-application theming is opt-out
rather than opt-in. Glance's HSL values in `glance.nix` are the same palette
written by hand, because that module takes raw colours.

### provisioning

Follow the [provisioning sequence](./README.md#provisioning-a-new-host).
Host-specific disk layouts and drive `by-id` paths live in `hosts/<host>/disko.nix`;
shared layouts live in `modules/disko`. The boot loader follows the
hardware: the OVH profile selects GRUB, workstations enable lanzaboote, and
Helium enables systemd-boot in its own host file. Workstations use LUKS on mdraid RAID1,
unlocked by a FIDO2 YubiKey, under lanzaboote-signed Secure Boot. Read the
[BIOS decisions](./README.md#do-not) before reinstalling one.
