# 02 - hosts

Five hosts, three trust zones.

## workstations (trusted, physically controlled)

### uranium - desktop
AMD GPU + Intel CPU, Hyprland, LUKS-on-btrfs via
`disko/luks-btrfs-uranium`. Primary dev + gaming machine. Runs ollama
locally because the AMD GPU is the only place it makes sense. Secure
boot via lanzaboote.

### tungsten - laptop
NVIDIA Optimus + Intel CPU, Hyprland, LUKS-on-btrfs with fido2 (yubikey)
unlock. Secondary dev machine. Hardware profile enables the laptop
profile (TLP, brightness, lid). SDDM autologin is intentional: LUKS +
yubikey is the real barrier, and the laptop is never left
unattended-unlocked in practice.

## local server (trusted LAN)

### helium-01 - homestead server
In-home server on a trusted LAN. Runs the "stuff I want to keep forever
but do not want on the public internet" pile: immich, paperless. Also the borg backup target for every other host (see
[06-backups.md](06-backups.md)).

No public ingress. Services are reachable over tailscale.

## public-facing servers (hostile network)

### carbon - primary OVH box
The public internet face of mischief.town. Runs caddy as reverse proxy
in front of:
- forgejo (git.mischief.town)
- vaultwarden (vw.mischief.town)
- PDS (atproto personal data server)
- grafana
- minecraft `mavs`

Public SSH is key-only, fail2ban enabled with tailnet allowlist. See
[07-security-posture.md](07-security-posture.md).

### argon - secondary OVH box
A second OVH box to spread load and reduce blast radius. Runs:
- hash-haus
- forgejo-runner (3 docker + 2 native)
- caddy
- minecraft `tbd`

Carbon and argon share enough boilerplate that an `ovh-server` profile
module is a planned refactor.

Note: forgejo-runner currently runs on carbon, argon, **and** helium-01
(each with 3 docker + 2 native runners). Spreading runners across hosts
means CI capacity does not bottleneck on one box; the downside is that
runner code executes on the same hosts as user-facing services. A
longer-term goal is to consolidate runners onto argon and helium-01
only, so carbon (which hosts vaultwarden and the PDS) stops running
untrusted pushed code.

## why five, not one big one

Separation of blast radius. A home ISP outage should not take down the
public git host. An OVH billing failure should not wipe family photos.
A compromised hash-haus should not touch vaultwarden. Each host leans
toward one trust-level of work, and the only crossings are
tailscale-gated.
