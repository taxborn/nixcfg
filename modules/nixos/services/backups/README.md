# borg/borgmatic backups

borgmatic client and borg repository server, with agenix-managed secrets. Every
host writes each archive to two places: rsync.net off-site, and Helium's external
drive over the tailnet.

## architecture

- borgmatic runs from its packaged systemd timer (daily) on each client
- one borgmatic configuration per repository, because `remote_path` is a
  per-config setting and rsync.net needs `borg14`; a single timer run walks all
  of them
- repositories live at `~/borg/<hostname>` on rsync.net and
  `/mnt/hdd/borg/<hostname>` on Helium
- Helium is both a client and the server; it reaches its own repository by local
  path rather than ssh'ing to itself
- passphrase and SSH key are per-host agenix secrets, readable only by that
  host's key (and my yubikey)
- hosts running a database swap the live files for a consistent logical dump
  inside every archive — `postgresqlDumpAll` for a cluster, `sqliteDatabases`
  for a file (see [databases](#databases))

The server's paths and the clients' targets both derive from one `backupServer`
attrset at the top of `default.nix`. There is exactly one backup server, so
those are constants rather than options — changing them in one place moves both
halves at once, and no host can set them out of sync.

### server side

Helium serves repositories over SSH on the `taxborn` user. Each client's public
key gets an `authorized_keys` entry with a forced command:

```
command="…/borg serve --restrict-to-path /mnt/hdd/borg/<client>",restrict <key>
```

The forced command replaces whatever the client asks to run, so the key can do
nothing but serve that one repository. `restrict` additionally drops pty
allocation, port forwarding, agent forwarding, and user rc.

### why the borg port is not 22, and why Helium alone has no Tailscale SSH

That forced command is only worth anything where sshd is the thing answering,
and for a while here it was not. Both halves of this are deliberate:

**Clients address Helium on `server.sshPort` (2222), not 22.** Tailscale SSH
takes port 22 on the tailnet address and authorises by tailnet identity, never
reading `authorized_keys` — so on 22 the `--restrict-to-path` restriction is
simply not applied, whatever it says in the file. Tailscale intercepts only 22,
so any other port is real sshd with the forced command in force. The port is
absent from `allowedTCPPorts`; the tailscale interface is in
`trustedInterfaces`, so it is reachable over the tailnet and nowhere else.

**Helium sets `myNixOS.services.tailscale.enableSSH = false`.** The port move
alone would not have been enough. Every repository lives on an ntfs-3g mount
with `uid=1000,umask=0000`, so every archive is owned by `taxborn` and
world-writable — a client that got compromised could ignore borg entirely, open
a shell on 22 by tailnet identity, and delete the lot. Turning Tailscale SSH off
here closes that path; Helium is the one host where a forced command is a
security boundary rather than a convenience.

Verify the distinction on any host — `"none"` means tailscaled answered and no
`authorized_keys` was consulted:

```bash
ssh -v taxborn@<tailnet ip> id 2>&1 | grep 'Authenticated to'
```

The consequence is that Helium is reachable only with a real SSH key
(`keys/yubikey.pub`, already in its `authorized_keys`). Tailnet identity is no
longer enough, so a machine with no key loaded cannot get in at all.

`borg-repo-base.service` creates `/mnt/hdd/borg` at boot. It runs as `taxborn`
and carries `RequiresMountsFor`, so it does nothing when the external drive is
absent — the drive is mounted `nofail`, and `/mnt/hdd` itself is root-owned
`0755`. That combination means a missing drive makes backups fail loudly instead
of quietly filling Helium's root filesystem with archives.

> The pre-rebuild archives from the old config still sit in
> `/mnt/hdd/borg-repos/`. They use different passphrases and keys, so nothing
> here can append to them; they are read-only history until the rebuild settles
> and they can be deleted.

## provisioning a host

Order matters: the secrets have to exist before the host rebuilds, or
activation fails on a missing `.age` file.

### 1. generate key material

```bash
ssh-keygen -t ed25519 -C "borg-<hostname>" -f /tmp/borg_ssh_key -N ""
openssl rand -base64 32 > /tmp/borg_passphrase
```

### 2. encrypt with agenix

`secrets/secrets.nix` already derives rules for every host in its `hosts` list,
so nothing needs adding there for an existing host. Run from `secrets/`, not the
repo root — agenix looks up the file argument as a rule name verbatim:

```bash
cd secrets
mkdir -p borg/<hostname>
agenix -e borg/<hostname>/passphrase.age < /tmp/borg_passphrase
agenix -e borg/<hostname>/ssh_key.age < /tmp/borg_ssh_key
```

`agenix -e` decrypts an existing target before writing, so to *replace* a secret,
delete the `.age` file first rather than piping over it.

The public key belongs in-repo — Helium's `server.authorizedKeys` reads it:

```bash
cp /tmp/borg_ssh_key.pub borg/<hostname>/ssh_key.pub
```

### 3. authorize the key on both servers

On Helium, add the host to `hosts/helium/default.nix` and rebuild it:

```nix
myNixOS.services.backups.server.authorizedKeys.<hostname> =
  builtins.readFile "${self}/secrets/borg/<hostname>/ssh_key.pub";
```

rsync.net's restricted shell blocks redirection (`>`/`>>`), so edit its
`authorized_keys` by round-tripping it over scp:

```bash
scp rsync-backup:.ssh/authorized_keys /tmp/rsync_authkeys
cat /tmp/borg_ssh_key.pub >> /tmp/rsync_authkeys
scp /tmp/rsync_authkeys rsync-backup:.ssh/authorized_keys
rm /tmp/rsync_authkeys
```

### 4. create the remote directory

Borg will not create the repository's parent. Helium's is handled by
`borg-repo-base.service`; rsync.net's restricted shell has no `mkdir`, so use
sftp:

```bash
sftp rsync-backup
sftp> mkdir borg
```

### 5. rebuild

Deploy before initializing: `borgmatic repo-create` reads the config and secrets
from the deployed system.

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

### 6. initialize the repositories

Run on the host as root, once per repository. The first connection to each
server has to accept its host key, which is why this step is interactive —
Helium's key is already pinned via `mySnippets.ssh.knownHosts`, rsync.net's is
not.

```bash
sudo borgmatic repo-create --encryption repokey-blake2
sudo borgmatic create --verbosity 1 --list
```

To (re)initialize one target only, pass its label:

```bash
sudo borgmatic repo-create --encryption repokey-blake2 --repository helium
```

### 7. clean up

```bash
shred -u /tmp/borg_ssh_key /tmp/borg_passphrase
rm /tmp/borg_ssh_key.pub
```

## operating

Run as root; configs live in `/etc/borgmatic.d/`, one file per repository.
Subcommands are borgmatic 2.x, and `--repository <label>` narrows any of them to
a single target.

```bash
sudo borgmatic create --verbosity 1 --list   # back up now
sudo borgmatic repo-list                     # archives per repository
sudo borgmatic list --archive latest         # files in the latest archive
sudo borgmatic repo-info                     # size, dedup stats
sudo borgmatic check                         # integrity check
sudo borgmatic extract --archive latest --path etc/ssh
sudo systemctl status borgmatic.timer
```

On Helium, the served repositories are inspectable directly:

```bash
sudo borg list /mnt/hdd/borg/argon
```

## databases

Copying a database's files while something is writing to them is not a backup.
borg walks them over a stretch of time during which the writes keep coming, so
what lands in the archive is a torn mix of pages whose recoverability depends on
where the commits happened to fall. It usually works, which is the dangerous
part.

So the live files are excluded and borgmatic's database hooks put a logical dump
in the archive instead — taken through the database's own code, consistent by
construction, streamed into each archive as it is written:

| option | engine | dump | what it excludes |
| --- | --- | --- | --- |
| `postgresqlDumpAll = true` | PostgreSQL | `pg_dumpall` of every database | `/var/lib/postgresql` |
| `sqliteDatabases.<name> = <path>` | SQLite | `sqlite3 <path> .dump` | `<path>*` |

Carbon uses the SQLite hook, for Forgejo. Nothing uses the PostgreSQL one at the
moment — Forgejo did until it moved to SQLite, and the option stays because the
next service with a cluster behind it (Immich, Paperless) needs it.

The SQLite exclude carries a trailing glob for a reason: `-wal` and `-shm` sit
beside the database file and hold everything committed since the last
checkpoint. Archiving those out of step with the file they belong to is worse
than archiving neither, because recovery reads the pair and trusts it.

**An exclude can silently eat the dump.** borgmatic stages dumps on disk and
hands borg the staging path as an extra source, so any exclude covering that
path drops the database from the archive while everything still reports success.
The path depends on how borgmatic was started — `/run/borgmatic` under the
packaged unit (`RuntimeDirectory=borgmatic`), `/tmp` when run by hand, as the
restore test does — so the module removes `/run`, `/tmp`, and `/var/tmp` from
the exclude list on any host taking dumps. They were inert for file selection
anyway, since `paths` never traverses them.

This is not hypothetical: it is exactly what happened on the first real run
here, and nothing surfaced it except the dump assertion in the restore test.
Anything that adds a database hook later — Immich, Paperless — inherits the
same trap.

Details in the module that are load-bearing and worth not "cleaning up":

- The SQLite hook takes **no** `username`. borgmatic reads the file directly and
  the unit already runs as root, so there is nothing to switch to. The nixpkgs
  module fills in `sqlite_command` from `pkgs.sqlite` on its own.
- The PostgreSQL dump, when something uses it again, must be declared as
  `{ name = "all"; username = "postgres"; }` and nothing else. That precise
  shape — a `username`, no `password`, no `pg_dump_command` — is what makes the
  nixpkgs borgmatic module both wrap the dump in `sudo -u postgres` *and* relax
  its own hardened unit (`NoNewPrivileges=false`, `CAP_SETUID`/`CAP_SETGID`) so
  that switch is allowed. Writing the equivalent command by hand opts out of the
  relaxation and the dump dies with `cannot set groups: Operation not
  permitted`. Note the relaxation is keyed on the PostgreSQL hook alone, so a
  host taking only SQLite dumps keeps the hardened unit — which is fine, and is
  why the SQLite hook must not grow a `username`.
- borgmatic runs one configuration per repository, so the dump is taken once
  per target. That is a little redundant and entirely intentional: each archive
  is independently complete.

Restoring is a separate verb from extracting files:

```bash
sudo borgmatic restore --archive latest                  # all databases
sudo borgmatic restore --archive latest --database forgejo
```

For SQLite this **overwrites the live file at its configured path** — borgmatic
removes it and replays the dump into a new one. Stop the service first, or it
will be holding a database that no longer exists.

This writes to the *live* cluster, so it is not something to run as a test —
tier 1 below asserts the dump is present in the archive without touching the
running database.

## testing restore

A backup that has never been restored is a hypothesis. Three tiers, cheapest
first; each one proves something the tier below it does not.

Everything at once, from a workstation:

```bash
just restore-all
```

Runs all three tiers against all three hosts and both repositories, continues
past failures rather than stopping at the first, and prints a pass/fail summary
at the end. It is interactive by nature — a yubikey touch per decrypt and a sudo
prompt per host — so it is not something to put on a timer. The individual
recipes below are what to reach for when one line of that summary says `FAIL`.

### tier 0 — key material

```bash
just restore-keys
```

`secrets.nix` encrypts each host's passphrase and SSH key to that host's root
key *plus* my yubikey, and nothing else. If a host is destroyed, the yubikey is
the only thing left that can open its archives — so this is the highest-value
check in the list, and it costs seconds. Run it from a workstation, not a
server.

`agenix -d` only tries the default ssh keys on its own — `age.identityPaths` is
a system-level setting and does not reach the CLI — so the recipes pass
`-i ~/.config/age/yubikey-identity.txt`. Override with `AGE_IDENTITY` if the
identity lives elsewhere.

### tier 1 — canary round-trip, per host, per repository

```bash
just restore-test argon
```

Writes a timestamp to `/var/lib/backup-canary`, runs `borgmatic create`, then
extracts that one file from *every* configured repository and diffs it against
the original. Repositories are discovered from `/etc/borgmatic.d/`, so a third
target is covered as soon as it deploys.

On a host taking database dumps, the script additionally asserts that the
archive really contains the matching `postgresql_databases/` or
`sqlite_databases/` directory. Which hooks to check it reads out of the
borgmatic config on disk, so a host that gains an engine is covered without the
script changing. The canary check alone cannot catch a failed database hook: the
live files are excluded either way, so an archive with no database in it
restores files perfectly and has silently lost everything Forgejo stores outside
the repositories themselves — users, keys, issues, and the mapping from a
directory on disk to a repository anyone can see.

The byte comparison is the assertion, not borg's exit code: an `--path` that
matches nothing still exits 0 and leaves an empty destination. Three related
traps, all baked into the script:

- `--destination` must already exist — borgmatic chdirs into it rather than
  creating it, and fails with `[Errno 2] No such file or directory` if absent.
- extracting into a directory that already holds a previous run collides on
  `etc/static` (`[Errno 17] File exists`), because that symlink points into
  `/nix/store`. Always extract into a freshly emptied directory.
- the dump assertion greps a here-string, never a pipe. `grep -q` exits at the
  first match, which SIGPIPEs a producer still writing an archive listing much
  larger than the pipe buffer; under `set -o pipefail` the pipeline then reports
  141 and the assertion inverts, calling a dump that is present missing. It is
  not a race — borgmatic injects the dump patterns at the head of the pattern
  list, so the match is always in the first few lines of a listing with the
  whole of `/home`, `/var/lib`, and `/etc` still to come. `just restore-all`
  had the same shape in its summary, where the inversion would have hidden
  failures rather than invented them.

Note that on Helium the `helium` repository is a local path, so that iteration
exercises no SSH at all. Helium's role as a *server* is only covered when a
client runs tier 1 — run it on Argon or Carbon to exercise the
`--restrict-to-path` forced command.

The scheduled integrity checks can also be forced on demand, independent of
their `frequency`. This reads the whole repository and is slow, which is why it
is not part of `restore-test`:

```bash
sudo borgmatic check --repository rsync --force
```

### tier 2 — disaster rehearsal

Tier 1 runs on a healthy host that already has its own secrets mounted, which
is not the scenario any of this insures against. Tier 2 restores a host's data
from a machine that holds none of it, using only the yubikey:

```bash
just restore-dr argon                    # off-site copy, on rsync.net
just restore-dr argon helium             # second copy, on Helium's drive
just restore-dr argon rsync helium       # both, on one pair of yubikey touches
```

Decrypts that host's key material to `/run/user/$UID` (tmpfs, `0700`, shredded
on exit), then for each named repository pulls the latest archive name, extracts
the canary, and compares it against the live host if it is still reachable.
Passing both repositories means the host is genuinely recoverable from either
copy with nothing but the yubikey.

The decryption happens once regardless of how many repositories are named, since
each `agenix -d` costs a yubikey touch. Naming both is strictly cheaper than two
invocations.

Reaching the Helium repository from a third machine works *because* of the
forced command, not in spite of it: the key being used is the client's own, and
`--restrict-to-path` confines it to exactly the repository being read. Both
Helium's tailnet address and the borg port come from `nix eval` against the
modules rather than literals, so the recipe cannot drift from them — and the
port is non-default precisely so the forced command is applied at all.

`just restore-dr helium helium` is therefore impossible and exits with a note
pointing elsewhere — Helium reaches its own repository by local path and holds
no key entry for itself. Verify that one on the host:

```bash
sudo borg list /mnt/hdd/borg/helium
```

Doing it by hand, the two things that bite:

- `repo::` takes the archive *name*, not the ID. `borg list` prints name,
  timestamp, and ID; copying the wrong column gives `Archive … does not exist`.
  Let `--last 1 --format '{archive}{NL}'` pick it instead.
- `ssh <host> <command>` fails with `Cannot execute command-line and remote
  command` wherever the SSH client config sets `RemoteCommand`. Add
  `-o RemoteCommand=none`, the same workaround `just update` uses for
  `nixos-rebuild`.
- that same config sets `RequestTTY yes`, which allocates a pty whenever ssh
  itself has a local tty — and a pty translates LF to CRLF. Reading a file that
  way returns a trailing `\r` that command substitution does *not* strip, so a
  byte comparison fails against content that is visibly identical. Pass
  `-o RequestTTY=no` **and** pipe through `tr -d '\r'`: the option loses to an
  explicit `-t`/`-tt`, so neither alone is sufficient. This only reproduces from
  an interactive shell, which makes it easy to miss when testing from a script.

### what a real restore actually looks like

Not `borg extract` with no path argument. Most of a host's `/etc` is symlinks
into `/nix/store` (`etc/static` among them), and a recovered host gets that
directory regenerated by rebuilding from the flake. Extracting the archive's
`/etc` over it fights nix rather than helping it. The order is:

1. rebuild the host from the flake — this restores `/etc`, `/nix`, and every
   service's configuration
2. restore only the state the flake cannot reproduce: `/var/lib` for service
   data, `/home` for everything else
3. run that step as root with `--numeric-ids`, or ownership and modes come back
   wrong

Tiers 1 and 2 extract as a single small file for speed, which deliberately does
*not* verify ownership. Once a service with real state exists, do one `sudo`
restore of its `/var/lib` directory to confirm permissions survive the trip.

> `authorized_keys` on rsync.net holds bare public keys with no forced command,
> unlike Helium's `--restrict-to-path` entries. Any host's borg key can
> therefore read *and delete* every other host's repository there, so one
> compromised VPS can take out all three off-site copies. Worth closing with
> `command="borg14 serve --restrict-to-path …"` entries.

## options

### `myNixOS.services.backups.client`

| option | type | default | description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | enable the borgmatic client |
| `paths` | list of str | `[ "/home" "/var/lib" "/etc" ]` | directories to back up |
| `extraExcludes` | list of str | `[ ]` | exclude patterns on top of the defaults |
| `repositories` | attrsOf { path, label, remotePath? } | rsync.net + Helium | targets to back up to |
| `retention.keepDaily` | int | `7` | daily archives to keep |
| `retention.keepWeekly` | int | `4` | weekly archives to keep |
| `retention.keepMonthly` | int | `6` | monthly archives to keep |
| `retention.keepYearly` | int | `1` | yearly archives to keep |

A directory containing `.nobackup` is skipped.

### `myNixOS.services.backups.server`

| option | type | default | description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | serve borg repositories over restricted SSH |
| `authorizedKeys` | attrsOf str | `{ }` | client hostname -> that host's borg SSH public key |

## enabling on a host

```nix
myNixOS.services.backups.client = {
  enable = true;
  extraExcludes = [ "/var/lib/containers" ];
};
```

Both repositories are added automatically —
`ssh://de4388@de4388.rsync.net/./borg/<hostname>` and
`ssh://taxborn@<helium tailnet IP>//mnt/hdd/borg/<hostname>`. Naming an
attribute replaces that target:

```nix
myNixOS.services.backups.client.repositories.rsync.path =
  lib.mkForce "ssh://de4388@de4388.rsync.net/./borg/<hostname>-alt";
```
