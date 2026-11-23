# services

What each service module does that is not obvious from the code. Every service
listens on loopback behind Caddy (see [network](./network.md)), keeps its
secrets in agenix rather than `settings` (which nixpkgs renders into the
world-readable store), and registers its own database dump with the backup
client (see [backups](./backups.md#databases)).

| service | host | state | dump |
| --- | --- | --- | --- |
| atuin | argon | postgres | `pg_dumpall` |
| glance | argon | none | |
| minecraft | argon, carbon | worlds under `/var/lib/minecraft` | servers stopped during the run |
| ntfy | argon | rebuilt from the secret | excluded |
| piper | argon | SQLite | `sqlite3 .dump` |
| tangled knot | argon | git under `/var/lib/knot` | files |
| tranquil-pds | argon | postgres plus blobs | `pg_dumpall` |
| vaultwarden | argon | SQLite | `sqlite3 .dump` |
| braxton-is | carbon | releases from CI | releases excluded |
| tangled spindle | carbon | SQLite with CI secrets | `sqlite3 .dump` |
| paperless | helium | postgres plus documents | `pg_dumpall` |
| monitoring server | helium | see [monitoring](./monitoring.md) | excluded |

## pinned services

Tranquil, Piper, Tangled, Albedo and the `tg` CLI are deployed by moving a flake input. Each is
pinned to a commit in `flake.nix`, so `nix flake update` leaves them alone. To
upgrade one, edit its `rev` and run `nix flake lock`. They were unpinned until
2026-11-10, and routine lock updates upgraded the PDS five times without
anyone asking.

Rolling back the PDS does not undo its database migrations. Piper alters its
SQLite schema on startup, and a rollback does not undo that either. Take a
dump first (`sudo borgmatic create --verbosity 1 --list`).

## albedo

A coding agent daemon on Helium, run as the `agent` user with no sudo, so it
cannot read the backup repositories or the Paperless archive. Lingering keeps
its user services up with no login.

- The web client is served at `albedo.biscuits.at` through Helium's tailnet-only
  Caddy, which is what gives the page HTTPS, notifications and the clipboard. It
  runs `--local`, so it listens on loopback and Caddy is the only way in, and
  `--public-url` names the origin it answers to. The name is a public A record
  holding Helium's tailnet address, like Paperless and Grafana. The sign-in link
  is in `journalctl --user -u albedo-web` as `agent`, so treat that journal as
  secret.
- Do not use `--tailnet-https`. `tailscale serve` takes port 443 on Helium's
  tailnet address inside `tailscaled`, ahead of Caddy, and every other tailnet
  node then gets a TLS internal error from Grafana and Paperless. The flag has
  no port option.
- `gh` and `tg` are on its PATH, `tg` from the pinned `tg` input. Their logins
  are manual as `agent` (`gh auth login`, `tg auth login braxton.is`). Scope
  those credentials to what the agent should touch, since it can use them
  unreviewed. The signing key is not one of them in name only: it is also the
  `tangled` ssh identity, so it authenticates pushes to the knot too.
- The provider login is manual: `albedo login` once as `agent`. Settings
  declared under `services.albedo.settings` land in the Nix store.
- Activation merges into files the daemon also writes. Stop it first with
  `albedo daemon --stop`, or the merge can be overwritten.
- Commits are signed with an ed25519 key generated on first activation at
  `~/.ssh/id_ed25519_signing`, with the agent's own identity. Register
  `~/.ssh/id_ed25519_signing.pub` as a signing key on the forge. A signature
  means the agent wrote the commit, not that you reviewed it.
- `~/.albedo` is excluded from backups because it holds live SQLite.

## atuin

History is encrypted on the client, so the dump holds ciphertext. It is still
the only copy a new machine can sync from.

Registration is closed, because the server is reachable from the internet and
anyone who registers can store data on it. To create an account, set
`homelab.atuin.openRegistration = true` for one deploy, run `atuin register` on
a client, then turn it off and deploy again.

## glance

The status probes run from Argon against the public names, so a red tile means
the whole path is broken (DNS, Cloudflare, Caddy, the app), not just the
process. Host liveness is whether node_exporter answers on the tailnet.
Workstations are in their own widget because they are expected to be red when
asleep. The server-stats widget shows Argon only.

The auth values are written as `\${...}` so Glance expands them from its
environment file at runtime instead of Nix putting them in the store. The theme
is Catppuccin Mocha typed out as HSL, because there is no catppuccin module for
Glance.

## ntfy

Users, ACLs and tokens are provisioned from `secrets/ntfy.age`.
`auth-default-access = "deny-all"`, because ntfy's default lets anyone who can
reach the vhost read and publish to any topic. `behind-proxy` is safe because
Caddy's `client-ip` snippet replaces `X-Forwarded-For`. `upstream-base-url` is
unset: it would route polls through ntfy.sh for iOS push, which is the one
setting that would talk to a third party. Android needs none of it.

The state directory is excluded from backups. Everything in it is rebuilt from
the secret or is a disposable cache, and it holds two live SQLite files.

## vaultwarden

The vault is dumped through SQLite rather than archived as live files, and
`backupDir` stays null. `ROCKET_ADDRESS` is loopback. Until `f1bdfff` it was an
explicit `0.0.0.0`, and only the closed firewall kept the vault off Argon's
public address.

## mail

Every service that sends mail relays through Fastmail on port 465, implicit TLS
(`force_tls` in Vaultwarden, not `USE_TLS` in Paperless, which is the STARTTLS
setting and conflicts). The login is `homelab.owner.email`. The sender is
`homelab.mail.from` at the `biscuits.at` apex. SPF and DKIM sit at the apex and
do not cover subdomains, so sending as anything under `pds.biscuits.at` or
similar is unauthenticated mail. A smarthost rather than direct MX, because
these hosts have no useful reverse DNS. Paperless sends password resets to
the owner's mailbox, not to `infra@`, which is a send-only identity.

## paperless

- PostgreSQL, not the default SQLite. Paperless only migrates between engines
  through a full export and re-import, so this was decided at install.
- `domain` becomes `PAPERLESS_URL`, the CSRF origin and the allowed Host, so a
  request under any other name (such as Helium's bare tailnet address) is
  refused.
- `PAPERLESS_OCR_LANGUAGE` is unset on purpose. The NixOS module takes the mere
  presence of the setting as a request to rebuild tesseract with only those
  languages, which swaps cached binaries for a local build of tesseract,
  ocrmypdf and Paperless. Set it only to add a language.
- The admin password in the environment file is required on first start.
  Without it `manage_superuser` does not run and there is no account to log in
  with.
- An overlay relaxes paperless-ngx's `torch<2.15` bound, since torch is only
  used by the optional classifier. Drop it once nixpkgs ships a paperless that
  accepts 2.15.

## piper

Provider credentials and Piper's ATProto key go in agenix, because the upstream
module renders `settings` into the store. It is proxied only because Spotify
and Last.fm need a public OAuth callback.

## tranquil-pds

- The server and its frontend come from the same pinned tree. The server serves
  `settings.frontend.dir`, and mixing the flake's server with nixpkgs' frontend
  breaks the web UI.
- PostgreSQL, not the embedded `tranquil-store`, which upstream calls
  experimental with a risk of total data loss. Nothing migrates between them.
- Postgres holds every account's repository, its encrypted signing key and the
  firehose sequence. Blobs sit under `/var/lib/tranquil-pds/blobs` and are
  archived as files.
- `MASTER_KEY` encrypts every signing key. Lose it and the repositories are
  gone, leak it and the identities are.
- Handles are `<name>.pds.biscuits.at`, resolved over HTTPS at
  `/.well-known/atproto-did` from the Host header. That is why the wildcard
  record and vhost exist and why neither can be proxied.
- `invite_code_required = true` is what keeps the PDS personal. The first code
  is printed to the journal on first start.
- `trusted_proxy_count = 1` matches the single Caddy hop. A wrong value fails
  silently in rate limiting and device records.

## tangled knot

- Git over SSH listens on the tailnet address only, and `openFirewall = false`
  overrides upstream's default of opening it to the world. Opening it would
  also need a fail2ban jail, since this is the knot's own SSH server.
- `KNOT_MASTER_KEY` unseals the signing keys in `/var/lib/knot/sealed-keys`.
  They only work as a pair. Lose the key and the knot loses every repository's
  identity. Leak it and a copy of the sealed file is enough to sign as the knot.
- The knot advertises its first admin, the owner's DID, as its owner.
  `acl.admission = "closed"` means only admins create repositories.
- `git.object_format = "sha1"`, because GitHub cannot mirror SHA-256
  repositories. It is fixed per repository at creation.
- The XRPC rate limiter trusts `X-Forwarded-For` from loopback only.
- `legacy_admin_secret_env` is unset. It would enable Basic Auth as the owner on
  the public XRPC surface.
- There is no database. Git under `/var/lib/knot/repos`, the sealed keys, LFS
  and the SSH host key are archived as files.

## tangled spindle

- Upstream runs the spindle as root with rootful Docker for nixery, so a
  workflow can read anything on the host. Assertions keep it off the knot's
  host and off the backup server. `admission = "closed"` runs CI only for the
  owner and the allow-list, since anyone who can run a workflow can read that
  repository's secrets and reach the tailnet.
- Its P-256 signing key is in agenix so a rebuilt host keeps its identity.
- The database holds repository CI secrets in plaintext, so it is dumped into
  the encrypted archive, not copied live. Image layers and per-run clones are
  excluded.
- One job at a time, a one-hour workflow timeout (upstream's five minutes
  includes queue time), logs on disk instead of S3, and nixery limits sized to
  leave room for the website. The microVM total is 4608 MiB: the image declares
  4096 MiB and the spindle adds 96 MiB per VM, so 4096 would fit nothing.

## braxton-is

The site is not a flake input. Tangled CI builds it and streams a tarball to
Carbon over SSH, and a forced command (`deploy`) unpacks it into
`releases/<rev>` and writes the revision to `.deployed`. A root-owned path unit
watches that file and restarts the service, so the deploy user holds no
privilege. Rolling back the site is free.

- The deploy key's `authorized_keys` entry is `restrict`ed to the forced
  command. The spindle reaches it over Carbon's public address because its
  microVMs cannot route to the tailnet. Port 22 was already open, so that adds
  no exposure.
- The deploy user owns the tree and the service user only reads it.
- The unit has `ConditionPathExists` on the entry point, so a host deployed
  before CI has run is quiet instead of failing.
- `MemoryDenyWriteExecute` stays off because V8 executes the memory it writes,
  and Node aborts on startup with it on.
- `AF_NETLINK` is allowed because Astro's listen banner calls
  `os.networkInterfaces()` and glibc's `getaddrinfo` uses netlink. Without it
  every start logs `uv_interface_addresses returned Unknown system error 97`.
  The server still runs, which is the trap.
- `StateDirectory` gives Astro's relative `.astro/session` path somewhere
  writable.
- The release's prebuilt glibc binaries (sharp, lightningcss, rolldown) cannot
  load on NixOS. A route that uses `astro:assets` through sharp fails on first
  request.

## minecraft

- Servers are not generated. Each directory keeps its own
  `server.properties`, whitelist, mods and world, copied in by hand. The unit
  runs the launcher jar directly rather than the pack's `start.sh`, which waits
  for a keypress, checks Java on every start and can download a JDK. The pack's
  `variables.txt` is the reference for the JVM flags. `openFirewall` opens the
  port TCP and UDP (voice chat mods, Bedrock clients), the one deliberate
  exception to loopback-only.
- Every server runs as the `minecraft` user, never a person. The servers load
  third-party mods and take internet connections, and the owner is in `wheel`,
  which is a Nix trusted user and so root-equivalent.
- Worlds live under `/var/lib/minecraft/<name>` (mode 0750), inside the backup
  client's default paths. An assertion fails the build if one is not.
- The console is a FIFO at `/run/minecraft-<name>.stdin`. ExecStop writes
  `stop` and waits for the PID, because systemd sends SIGTERM the moment
  ExecStop returns and a modded world saves slowly. The stop timeout is five
  minutes. `restartIfChanged = false` keeps a switch from kicking players.
- `ConditionPathExists` on the jar stops a host deployed before its world
  arrives from looping on a missing jar forever. A skipped unit is quiet too,
  so check `systemctl status` after moving a world in.
- The sandbox makes the server directory the only writable path.
  `MemoryDenyWriteExecute` is off because HotSpot is a JIT. `SystemCallFilter`
  is off because mods ship native libraries, and a filtered call is a SIGSYS
  mid-session.
- `-Dlog4j2.formatMsgNoLookups=true` covers packs with an old log4j.
- fail2ban watches for the scanner signature (a `DecoderException` on a
  truncated handshake) on hosts that open the port.
- mc-monitor cannot set a listen address, so its unit allows only loopback and
  the tailnet. process-exporter reports RSS, which is what grows past the fixed
  heap and what the OOM killer reads.
- Nightly backups stop every server and start them again in `ExecStopPost`, so
  the archive holds an idle world. The stop is `-` prefixed so a hung server
  cannot block the backup. A `Conflicts=` edge would let a server start stop
  borgmatic mid-archive. A manual `borgmatic create` does not go through this
  and archives a live world.
