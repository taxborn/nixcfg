# network

Every service listens on `127.0.0.1` and Caddy is the only way in. No service
opens a firewall port unless its host opts in, and the only one that offers to
is Minecraft, which speaks a protocol Caddy cannot front.

## caddy postures

`modules/nixos/server.nix` imports Caddy on every server. Each host picks one of
two postures in its `proxy.nix`, and the module refuses both at once.

| posture | host | 80/443 | certificates |
| --- | --- | --- | --- |
| `homelab.caddy.cloudflareOnly` | argon, carbon | Cloudflare's ranges only | HTTP-01, plus DNS-01 for the PDS wildcard |
| `homelab.caddy.tailnetOnly` | helium | closed | DNS-01 for everything |

### cloudflareOnly

Two checks, because each proves something different.

- **The IP allowlist** proves a request came from Cloudflare's network. Anyone
  with a Cloudflare account can arrange that by pointing a proxied record of
  their own at the origin.
- **Authenticated origin pulls** (`cloudflare-mtls`) prove it came from this
  zone. Caddy demands the client certificate Cloudflare presents on every
  origin pull, so no certificate means no handshake. The public half lives in
  `keys/cloudflare-origin-pull.pem`. The private half exists only in
  Cloudflare. Rotating it means generating a new pair, uploading it, and
  replacing that file. Every zone served this way needs the certificate
  uploaded, which includes `braxton.is` as well as `biscuits.at`. A zone
  without it gets a 525 on every request.

Every vhost on a `cloudflareOnly` host must `import cloudflare-mtls`. An
assertion makes a missing import a build failure rather than an open door.

The allowlist is copied from Cloudflare's published lists, and a range it is
missing is a partial outage that looks like Cloudflare's fault.
`just check-cloudflare-ips` diffs `caddy.nix` against
`https://www.cloudflare.com/ips-v4` and `ips-v6`.

The firewall rules use `iptables -w`, matching the ip46tables wrapper the rest
of the ruleset uses. Without `-w`, a fail2ban ban landing during a reload holds
the xtables lock, `firewall-start` exits non-zero under `sh -e`, and
`firewall-stop` then unhooks `nixos-fw` from INPUT entirely.

### tailnetOnly

Nothing on Helium is meant for the internet, so 80 and 443 stay shut and the
tailnet interface is the whole front door. That costs HTTP-01, which needs port
80 open to Let's Encrypt from anywhere, so every vhost solves DNS-01 with the
Cloudflare token. A vhost that does not fails issuance in a retry loop instead
of failing loudly.

Paperless (`docs.biscuits.at`) and Grafana (`grafana.biscuits.at`) are public
A records holding Helium's tailnet address. Anyone can resolve them and only
the tailnet can connect, and the browser still gets a real certificate. An
explicit record beats the zone's proxied `*.biscuits.at`, so those names never
reach Cloudflare's edge and need no `cloudflare-mtls`.

### directVHosts

The firewall works in addresses, not names, so 80/443 can only stay shut to the
world while every vhost on the host is behind the proxy. Listing a vhost in
`directVHosts` exempts it from the mTLS assertion and reopens 80/443 to
everyone on that host. The other vhosts keep the client-certificate check,
which is the one that authenticates.

The PDS is the only direct vhost. Its two names (`pds.biscuits.at` and
`*.pds.biscuits.at`, one label per account handle) are the only DNS-only
records in the zone. Any one of these reasons would be enough:

- The universal edge certificate covers `*.biscuits.at` and stops there. A
  proxied `alice.pds.biscuits.at` has no edge certificate and dies at the
  handshake.
- `com.atproto.sync.subscribeRepos` is a WebSocket that relays hold open
  through idle periods, and the proxy times those out.
- The free tier caps a request body at 100 MB. Blob uploads are allowed up to
  10 GiB.

The wildcard can only be issued over DNS-01. The token needs Zone:DNS:Edit and
Zone:Zone:Read on the zone. HTTP/3 is open on UDP 443 for the same names, never
narrowed to Cloudflare's ranges, matching TCP 443, which `directVHosts` already
opened.

The PDS vhosts send `{remote_host}`, the TCP peer, as the client address with
`header_up`, which replaces rather than appends. `trusted_proxies` is
server-wide and lists Cloudflare, so a connection from inside a Cloudflare
range would otherwise have a forged `X-Forwarded-For` believed and passed to
the PDS.

## client addresses

Caddy appends to `X-Forwarded-For` rather than replacing it, and never sends
`X-Real-IP`. The `client-ip` snippet hands every backend one authoritative
address. Without it the knot (`trusted_proxy_header`) and Vaultwarden
(`IP_HEADER=X-Real-IP`) see Cloudflare's edge or loopback.

`trusted_proxies_strict` reads `X-Forwarded-For` right to left. Cloudflare
appends the visitor's address to the right of anything the visitor sent, and
Caddy's default left-to-right read would take a header the visitor wrote
(`X-Forwarded-For: 1.2.3.4`) as their address. That would defeat the rate
limiters in Vaultwarden, ntfy and the knot. One gap remains: a visitor whose
own address is inside a Cloudflare range is skipped as a trusted hop.

## access logs

Direct vhosts write `direct-<name>.log` in Caddy's JSON so Alloy can ship it.
The filter runs before the line is written and drops `Authorization`, `Cookie`,
`Set-Cookie` and the query string, since those carry PDS session tokens, app
passwords and one-time OAuth codes. The file is `0640` so Alloy, in the `caddy`
group, can read it. The `direct-` prefix is what Alloy matches on, and it keeps
Alloy away from nixpkgs' unfiltered `0600` defaults. `remote_ip` in the log is
the TCP peer. `client_ip` trusts any Cloudflare range, so do not alert on it.

The wildcard vhost names its log explicitly. The default name would contain a
literal `*`.

## per-vhost notes

- **ntfy, the knot**: no `encode`. ntfy subscriptions and the knot's `/events`
  are long-lived streams, and compression buffers them. Git packs are already
  compressed. Cloudflare cuts a connection idle for 100 seconds, and ntfy's 45
  second keepalive stays inside that.
- **The knot**: no CORS headers at the proxy. The knot sets its own, and
  upstream warns that adding them breaks it. HTTPS pushes over 100 MB fail at
  Cloudflare, so pushes go over tailnet SSH.
- **Piper**: proxied only because Spotify and Last.fm send their OAuth
  callbacks to a public name.
- **The spindle**: needs its own proxied record pointing at Carbon. The zone
  wildcard lands on Argon, which has no certificate for the name, and
  Cloudflare would return a 525.
- **braxton.is**: the apex serves the site, matching the Astro config. `www`
  redirects, and still needs its own DNS record and certificate.

## the Cloudflare DNS token

The token can edit DNS, so only hosts with a vhost that solves DNS-01 decrypt
it: Argon for the PDS wildcard, Helium for everything. Carbon runs CI as root
and never holds it. Caddy derives whether it needs the token from its vhosts,
and the recipients in `secrets/secrets.nix` must name the same hosts. The
per-secret recipient check fails the build if they do not.

The `caddy-tailscale` plugin is not built in. Nothing uses its listener, and
`get_certificate tailscale` went with Forgejo's tailnet vhost.

## tailscale

`tailscale0` is a trusted interface, accepted before the port rules, which is
what makes any socket bound to a tailnet or wildcard address reachable over the
tailnet without opening a port. Loopback services are not covered, because
tailnet traffic never arrives on `lo`, so Caddy is still the way in to them.

Flags go in `extraSetFlags` (`tailscale set`), not `extraUpFlags`. The
autoconnect unit only runs `tailscale up` when the backend needs a login, so an
up-flag never reaches a node that is already on the tailnet. `--operator` is
the exception and is applied only on first join. Move it to `extraSetFlags` if
it ever changes.

`--ssh` makes tailscaled answer port 22 on the tailnet address itself and
authorise by tailnet identity. sshd is not involved on that path:
`authorized_keys` and `sshd_config` are never read. `ssh -v` reporting
`Authenticated ... using "none"` means tailscaled answered. This is why the
borg server needs a separate port (see [backups](./backups.md)).

The UDP port is open to the internet so peers connect directly instead of
through a relay. IP forwarding is on everywhere (`useRoutingFeatures = "both"`).
Whether a host actually routes is decided by the tailnet ACLs, which live
outside this repo (see TODO.md).

A service that binds the tailnet address merges `homelab.tailscale.bindOrdering`
into its unit. The address only exists once tailscaled is Running, and a unit
that loses that race on a cold boot would otherwise latch failed after
systemd's start limit.

## fail2ban

fail2ban hooks its chains onto the head of INPUT, ahead of the firewall's
accept for trusted interfaces. So `ignoreIP`, and not `trustedInterfaces`, is
what keeps a ban off the tailnet, and a ban on a tailnet address takes out the
path used to lift it. `ignoreIP` is the tailnet ranges and nothing else. A
public address stays bannable, including the owner's. The module asserts the
ranges cover every address in `homelab.hosts`. IPv6 addresses count as
uncovered, so a host that gains one trips the assertion instead of a ban.

SSH is the only jail, with `maxretry = 3`.

## ssh

Servers open port 22 to every interface. Carbon takes the site's deploy key on
its public address, and Argon and Helium want a way in when tailscaled is down.
Workstations close it (`homelab.ssh.openFirewall = false`). They run no
fail2ban, and the laptop joins networks nobody here controls. Tailscale SSH
still answers on the tailnet.

`services.openssh.openFirewall` defaults to true in nixpkgs, so the module sets
both it and the firewall rule from the option. It uses `mkDefault` because the
backup server sets it false for its own port and still wants 22 open.

Known-host pins come from `keys/root_<host>.pub` under each host's bare,
MagicDNS and tailnet-IP names. No `.local` names, since no host runs avahi. A
name left off falls back to trust-on-first-use.

## port allocation

Services take a port from the `300x` sequence in `homelab.nix`. 3002 was
Forgejo's and 3010 AdGuard's. The knot's tailnet SSH uses 2222, its own
default. Never write a port literal into a vhost. Read it from
`config.homelab.services`.
