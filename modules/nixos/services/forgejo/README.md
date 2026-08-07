# forgejo

Git forge on Carbon, at `git.mischief.town`, on SQLite.

## the shape of it

- web UI over HTTPS through Caddy, on the proxied Cloudflare record
- git over SSH on **Forgejo's own SSH server, port 2222**, **tailnet only**
- SQLite in the state directory — no database daemon, no database password
- one agenix secret (SMTP) plus a commit-signing key

Clone URLs:

```
ssh://git@carbon.tucuxi-hexatonic.ts.net:2222/owner/repo.git
```

Host, port, and web domain all come from one place,
`mySnippets.mischief-town.networkMap`.

## why SSH looks the way it does

Three constraints collide here. The result is not what the obvious reading of
this setup suggests, so it is worth writing down.

**Cloudflare's proxy carries HTTP(S) and nothing else.** Every name under
`mischief.town` resolves to a Cloudflare edge address via the proxied wildcard
`CNAME`. An `ssh://` URL pointed at `git.mischief.town` does not reach Carbon at
all — it opens a TCP connection to Cloudflare, which has no idea what to do with
it, and hangs. Git over SSH needs a name that resolves to the host itself, hence
the MagicDNS name.

**Tailscale SSH owns port 22 on the tailnet interface.** The tailscale module
passes `--ssh`, so `tailscaled` intercepts SSH to the tailnet address and
authorises it by *tailnet identity*, against the tailnet SSH ACL. It never reads
`authorized_keys`.

That second point rules out the arrangement this originally shipped with, which
was serving git from the host's sshd on port 22 with Forgejo maintaining
`authorized_keys`. It fails in exactly the environment it was meant for:

- Forgejo pins every registered key to a forced `forgejo serv` command. Tailscale
  SSH never sees that file, so the forced command is skipped and the client's own
  command runs against the account's shell. A clone dies with git-upload-pack's
  `does not appear to be a git repository`, because raw git got a Forgejo-relative
  path.
- Worse, it means any tailnet peer the SSH ACL admits gets **arbitrary command
  execution** as that account.

Confirm the interception directly — this reports `Authenticated ... using
"none"`, which is neither a key nor a password:

```bash
ssh -v -T git@carbon.tucuxi-hexatonic.ts.net 2>&1 | grep 'Authenticated to'
```

Note that only the tailnet interface is affected; the *public* address is still
plain sshd. So "confine git to the tailnet" and "serve git from sshd" are
mutually exclusive on this host: sshd's rules apply exactly where git traffic
does not, and vice versa.

**So git runs on Forgejo's builtin SSH server on port 2222**, which Tailscale
does not intercept. Keys are held inside Forgejo, there is no forced command to
bypass, and no login account is involved at all.

### tailnet-only, without binding to the tailnet address

Port 2222 is deliberately **not** in `allowedTCPPorts`. The tailscale interface
is in `trustedInterfaces`, so tailnet peers reach the listener while the firewall
drops it on the public interface.

Binding `SSH_LISTEN_HOST` to the tailnet address would be the other way to get
there, and a worse one: Forgejo would fail to start whenever `tailscaled` had not
yet assigned the address.

### the git account has no shell

Forgejo runs as `git` so clone URLs read `git@…`, but the account is given
`nologin`. Nothing authenticates as it — the builtin server answers git traffic
itself — and a shell would hand one to every tailnet peer the SSH ACL admits,
for the reason above. `SSH_CREATE_AUTHORIZED_KEYS_FILE` is off for the same
reason: a stale key file would be a second, unmanaged way in.

### consequences

- pushing requires being on the tailnet. That is the intended trade for now —
  single user, no off-tailnet CI. Undoing it means a publicly resolvable
  **DNS-only** (grey-cloud) record plus opening 2222; the web domain cannot be
  reused for it.
- clone URLs name the host rather than the service, so moving Forgejo
  invalidates stored remotes. Pointing `sshDomain` at a service-scoped DNS-only
  record would decouple them, at the cost of publishing a tailnet address in
  public DNS.

## note on Tailscale SSH generally

Worth knowing beyond Forgejo: because `--ssh` authorises by tailnet identity, it
bypasses `sshd_config` entirely — including `PermitRootLogin no`. On this host
`ssh root@carbon.<tailnet>` currently authenticates with `"none"`. Whether that
is acceptable is a tailnet **ACL** question, decided in the Tailscale admin
console, not in this repo.

## the 100 MB ceiling

Cloudflare's plan caps request bodies at 100 MB, and everything reaching the
web domain passes through it. That applies to:

- `git push` over HTTPS
- **Git LFS uploads, even when the remote is SSH** — LFS authenticates over SSH
  but transfers over the HTTPS endpoint derived from `ROOT_URL`

Plain git over SSH bypasses Cloudflare and has no such limit, so it is the path
for anything large. The `request_body max_size 2GB` in the vhost is a ceiling at
the origin, not a way around Cloudflare's.

## database

SQLite, at `/var/lib/forgejo/data/forgejo.db`. One user and one forge do not
need a second daemon to run, patch, and version-pin, nor a `pg_upgrade` day
whenever nixpkgs moves its default major. There is no password here for the same
reason there was none under PostgreSQL: nothing is listening, and access is
filesystem permissions on a file only `git` can open.

This started on PostgreSQL and moved. Should it ever need to move back, note
that Forgejo has no supported cross-engine conversion — `forgejo dump` writes
SQL in the dialect it read, so the paths are "start empty" or "adopt the
repositories from disk into a fresh instance".

`SQLITE_JOURNAL_MODE = "WAL"` is set, and it is about the backup rather than
about load. The dump hook is one long read across the whole database; under the
default rollback journal it holds a shared lock for that whole read, and any
write Forgejo attempts meanwhile — a push, or one of the crons — fails with
`database is locked` once `SQLITE_TIMEOUT` runs out half a second later. Under
WAL, readers and writers do not block each other and the backup is invisible to
the running service.

Backups are handled by the backups module's `sqliteDatabases`, set on Carbon.
It excludes the live file *and its `-wal`/`-shm` companions* in favour of a
`sqlite3 .dump` in every archive. Excluding the sidecars matters as much as
excluding the database: they hold everything committed since the last
checkpoint, and a copy of the pair taken moments apart is a torn pair that
recovery will read and trust. See that module's README.

## provisioning

### 1. SMTP password

A Fastmail app password for `hello@taxborn.com`. From `secrets/`, not the repo
root — agenix resolves the argument as a rule name verbatim:

```bash
cd secrets
agenix -e forgejo/mail.age < /path/to/app-password
```

The build succeeds without it — `age.secrets.*.file` interpolates `self`, so it
is already a store path string and Nix never checks it. The failure surfaces at
*activation* on the host, when agenix cannot find the file to decrypt. Create it
before deploying.

### 2. commit signing key

Already generated and committed (`secrets/forgejo/signing-key.age`, public half
alongside it). To replace it:

```bash
ssh-keygen -t ed25519 -C "forgejo@mischief.town" -f /tmp/fjkey -N ""
cd secrets
rm forgejo/signing-key.age              # agenix -e decrypts before writing
agenix -e forgejo/signing-key.age < /tmp/fjkey
cp /tmp/fjkey.pub forgejo/signing-key.pub
shred -u /tmp/fjkey; rm /tmp/fjkey.pub
```

Forgejo signs with `ssh-keygen -Y sign`, which wants the private key beside its
public half under the same basename — hence the tmpfiles symlink placing
`key.pub` next to the agenix-decrypted `key`.

### 3. deploy and create the admin account

```bash
just update carbon
```

Registration is disabled, so the first account is made by hand on the host:

```bash
sudo -u git forgejo --config /var/lib/forgejo/custom/conf/app.ini \
  admin user create \
  --admin --username taxborn --email hello@taxborn.com --random-password
```

`--config` is not optional and is not cosmetic. Run without it, the binary
resolves its work path relative to *itself* and goes looking for
`/nix/store/…-forgejo/custom/conf/app.ini`, finds nothing, and falls back to
defaults — which means a second, empty SQLite database somewhere under the store
path, and an account created in a database no running service will ever open.
`--config` is a global flag, so it goes before the subcommand.

The module puts `forgejo` and `sqlite3` in the system PATH for exactly this
reason; the nixpkgs module leaves the binary reachable only from inside the
unit.

### 4. add an SSH key and verify the path end to end

Add a public key through the web UI, then from a tailnet machine:

```bash
ssh -T -p 2222 git@carbon.tucuxi-hexatonic.ts.net
```

Expect Forgejo's own greeting (`Hi there, <user>! You've successfully
authenticated…`). Two ways this goes wrong, both worth recognising:

- `Authenticated ... using "none"` under `ssh -v`, or git-upload-pack's
  `does not appear to be a git repository` — the connection went to **port 22**
  and was taken by Tailscale SSH. Check the port.
- `Permission denied (publickey)` — the key is not registered in Forgejo, or
  the builtin server is not listening. `ss -tlnp | grep 2222` on the host.

Then a real clone:

```bash
git clone ssh://git@carbon.tucuxi-hexatonic.ts.net:2222/taxborn/test-repo.git
```

Confirm it is not public — from off the tailnet this must time out or refuse:

```bash
nc -vz 15.204.91.84 2222
```

## adding a forgejo actions runner

registration is offline, so nothing has to be minted from the web ui and
nothing has to be copied back out of it. one 40-character hexadecimal secret is
both the runner's identity and its password — forgejo derives the runner's uuid
from the first 16 characters, and the runner host derives the same uuid locally.

runners reach the forge at `git.<tailnet>`, a caddy vhost bound to a userspace
tailscale node on carbon — never at `git.mischief.town`. the runner rewrites
`GITHUB_SERVER_URL` and the artifact endpoints from whatever it connects to, so
cloning and artifact uploads take that path too.

1. add the hostname to `runnerHosts` in
   [secrets/secrets.nix](secrets/secrets.nix), so the secret is encrypted to
   carbon and to that host
2. `openssl rand -hex 20`, then paste it into
   `agenix -e secrets/forgejo/runner-<host>.age`
3. add the hostname to `myNixOS.services.forgejo.runners` on carbon, and set
   `myNixOS.services.forgejo.runner.enable = true` on the host itself
4. rebuild carbon first — it is what creates the runner — then the runner host

removing a runner is not symmetric: dropping it from the config stops carbon
asserting that it exists, but the row stays in the database. delete it from
`/admin/actions/runners`.

registration is closed on the instance, because an open signup form on a forge
with runners is an unauthenticated path to code execution on argon and helium.
accounts are made by hand:

```
forgejo --config /var/lib/forgejo/custom/conf/app.ini admin user create ...
```
