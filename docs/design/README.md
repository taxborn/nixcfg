# design

Architectural design decisions for the nix-infra flake. These docs capture
the "why" behind the structure so future-me (and anyone reading) does not
have to reverse-engineer intent from code.

Each doc is narrative, not reference material. Reference lives in the
modules themselves.

## index

- [01-repo-layout.md](01-repo-layout.md) - flake structure, module namespaces, inputs
- [02-hosts.md](02-hosts.md) - the 5 hosts, roles, trust boundaries
- [03-modules-and-profiles.md](03-modules-and-profiles.md) - enable/mkIf pattern, profile hierarchy
- [04-secrets.md](04-secrets.md) - agenix strategy, key scoping
- [05-networking.md](05-networking.md) - tailscale, caddy, mischief-town network map
- [06-backups.md](06-backups.md) - borg topology, restore posture
- [07-security-posture.md](07-security-posture.md) - public-facing vs LAN, fail2ban, SSH

Open code-level issues (not design decisions) live in
[`../backlog.md`](../backlog.md).

## writing a new design doc

When making a non-obvious architectural decision, add a doc here rather
than burying the reasoning in a commit message. Keep them short. Prefer
prose over bullet soup. Update the index above.
