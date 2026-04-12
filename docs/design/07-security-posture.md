# 07 - security posture

## trust zones

Three tiers, enforced by host placement, not by policy docs:

1. **Workstations** (uranium, tungsten) - physically controlled,
   full-disk encryption, yubikey-gated sudo and SSH, no inbound
   services beyond the tailnet.
2. **LAN server** (helium-01) - trusted LAN, no public ingress,
   services reachable only over tailscale.
3. **Public servers** (carbon, argon) - hostile network, assume
   someone is always scanning port 22.

The `myHardware.profiles.ovh` module captures the OVH-specific
baseline (grub, kernel modules, network config). The long-term plan
is a sibling `myNixOS.profiles.ovh-server` that also pulls in caddy,
fail2ban, node-exporter, fluent-bit, and backups, so carbon and argon
can flip one switch.

## SSH

- Password auth off everywhere.
- Root login off everywhere.
- X11 forwarding off everywhere.
- Key-only, with user keys coming from the secrets repo.

Public-facing SSH is still on port 22. Moving it would cut scanner
noise significantly, but it does not change the security model, so it
is a log-hygiene improvement rather than a hardening one.

## fail2ban

Enabled on every public-facing host. The tailnet CGNAT range is
whitelisted so my own automation does not ban me. Default jails
(sshd) plus opt-in jails per service (caddy, forgejo). The
`maxretry = 3`, `bantime = 1h` default is intentionally lenient; the
goal is to slow down scanners, not to lock out legitimate users on a
dropped packet.

## caddy and service isolation

Services behind caddy on carbon and argon bind to `127.0.0.1` or the
tailscale interface, never `0.0.0.0`. Caddy is the only process that
binds public ports. The firewall is default-deny and opens only:

- 22 (SSH)
- 80, 443 (caddy)
- per-service public ports (minecraft 25565, forgejo SSH 2222)

Any service that sneaks `networking.firewall.allowedTCPPorts` into
its own module without a clear reason is a bug.

## running user code (forgejo-runner)

Forgejo-runner executes arbitrary pushed code. It currently runs on
carbon, argon, and helium-01 (3 docker + 2 native runners each). This
spreads CI load but means runner code lives on the same boxes as
vaultwarden (carbon) and immich/paperless (helium-01). The planned
direction is to consolidate runners onto argon and helium-01 only so
carbon's trust surface shrinks. Runners talk to forgejo over
tailscale, not through the public caddy vhost, which at least keeps
job traffic off the internet.

## secrets at rest

See [04-secrets.md](04-secrets.md). Short version: agenix per-host,
scoped by public key, no secret in the nix store in plain text.

## what is explicitly not protected against

- Nation-state actors. Out of scope.
- Physical seizure of a powered-on workstation. LUKS only protects
  data at rest.
- Supply chain compromise of nixpkgs-unstable. I accept the tracking
  risk in exchange for fresh packages.
- Loss of the primary yubikey without a backup. This is a recovery
  hole that needs a second enrolled key.

Documenting the non-goals matters as much as the goals. "Defense in
depth" without a threat model is cargo culting.
