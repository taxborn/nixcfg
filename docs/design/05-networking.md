# 05 - networking

## tailscale as the control plane

Every host joins a single tailnet. Tailscale is the only cross-host
communication layer; nothing talks to anything else over the public
internet. This has a few consequences:

- Host-to-host firewalls can default-deny and only allow tailscale
  CGNAT range (`100.64.0.0/10`).
- fail2ban whitelists the tailnet range so my own traffic cannot get
  me rate-limited.
- helium-01 serves immich/paperless/copyparty reachable only via
  tailscale hostnames. No public DNS, no caddy vhost for them.
- forgejo-runner on argon reaches forgejo on carbon over tailscale
  instead of through public caddy, which avoids a hairpin and keeps
  runner traffic off the internet.

## caddy as the public face

Only carbon and argon run caddy with public 80/443 exposure. The
caddy config uses a mix of:

- vhost -> local proxy helpers (`localProxy`, `encodedProxy` in
  `hosts/carbon/proxy.nix`) for services on the same box.
- vhost -> tailscale hostname for anything that needs to be public-faced
  but runs elsewhere.

The `mySnippets.mischief-town.networkMap` snippet is the single source
of truth for `{ vhost, port }` mappings. Both caddy config and
documentation consume it, so there is exactly one place to update
when a port changes.

## DNS

mischief.town DNS is managed externally (not in this flake). A-records
point at carbon and argon. Everything else rides subdomains. This doc
does not track DNS state; see the registrar for that.

## why no wireguard mesh by hand

Tailscale handles NAT traversal, key rotation, ACLs, and MagicDNS for
free. Running wireguard directly would mean re-inventing all of that.
The dependency on a third-party coordinator (Headscale would be an
alternative) is an accepted risk; if it becomes a problem the migration
path is Headscale on carbon.
