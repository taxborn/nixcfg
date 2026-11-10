# borg/borgmatic backups

borgmatic client and borg repository server, with agenix-managed secrets. Every
host writes each archive to two places: rsync.net off-site, and Helium's external
drive over the tailnet. Uranium also writes to a local SSD.

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
  inside every archive, `postgresqlDumpAll` for a cluster and `sqliteDatabases`
  for a file (see [databases](#databases))

The server's paths and the clients' targets both derive from one `backupServer`
attrset at the top of `default.nix`. There is exactly one backup server, so
those are constants rather than options. Changing them in one place moves both
halves at once, and no host can set them out of sync.

### server side

Helium serves repositories over SSH on the `taxborn` user, on port 2200, over
the tailnet. Each client's borg public key is added to that user's
`authorized_keys`, and the backups module pins Helium's host key for that port
so a backup run cannot be asked to trust a new one.

Every host reaches every other over Tailscale SSH, which answers 22 on the
tailnet address and authorises by tailnet identity. That is why the borg keys
need a port of their own. Nothing is added to `allowedTCPPorts`, and the
tailscale interface is in `trustedInterfaces`, so the repositories are
reachable from the tailnet and nowhere else.

> Each client key is confined to `borg serve --restrict-to-path
> /mnt/hdd/borg/<client>` by a forced command, with `restrict`. It is served on
> port 2200 from real sshd, because on 22 Tailscale SSH answers and never reads
> `authorized_keys`. That port is not in the firewall and sshd binds it to the
> tailnet address alone (`listenAddresses`), so it is reachable over
> `tailscale0` only. Clients use `ssh://…:2200//mnt/hdd/borg/<client>`, and the
> backups module pins Helium's host key for `[ip]:2200`, since known_hosts
> matches a non-default port separately from 22.
>
> What this closes: a host's borg key can no longer read or delete another
> host's repository. What it does not: port 22 is still there. A host
> compromised badly enough can reach a shell on Helium by tailnet identity and
> wipe the drive, which only the tailnet ACLs can stop. Those live outside this
> repo, so check them. The keys are also not append-only, so a compromised host
> can still prune its own repository. Append-only would stop client-side prune
> and compact from reclaiming space, so it was left off. Every repository is
> owned by `taxborn` on one btrfs filesystem, and every key serves as that user,
> so file permissions are no boundary between repositories, and the forced
> command is the only one. They do keep other local users out: the tree is
> `0700`, so a compromised service account on Helium cannot delete archives.
>
> Deploy Helium before any client. A client rebuilt first points at 2200 before
> anything listens there, and notifications are success-only, so the failure
> is silent.
>
> rsync.net's `authorized_keys` carries the same confinement, one entry per
> host: `command="borg14 serve --restrict-to-path
> /data1/home/de4388/borg/<host>",restrict ssh-ed25519 … borg-<host>`. Nothing
> in this repo can confirm that, since the file lives on rsync.net and is
> edited by hand. A host added without the prefix is unrestricted there, with
> no error to say so. The operator's own `yubikey` entry stays bare.
> `just rsync-keys-check` fetches the file and diffs it against entries
> generated from `secrets/borg/*/ssh_key.pub`, reporting any host that is
> missing, unconfined, or pointed at another repository. It needs the
> yubikey. `just rsync-keys-test` exercises the generation and comparison
> offline.
>
> Those keys are not append-only either, so a compromised host can prune its
> own rsync.net repository, exactly as on Helium. The one copy it cannot
> prune is rsync.net's server-side snapshot schedule, which sits outside the
> borg key's reach. That makes the schedule the real floor on how much history
> survives a compromised host, and nothing in this repo records or checks it.
>
> Snapshot schedule, confirmed by the account owner on 2026-11-09: snapshots
> are kept for 7 days. A compromised host can therefore destroy history older
> than a week only if it also goes unnoticed for longer than that. Still to
> confirm: that the snapshots are not writable or deletable from the borg
> keys' restricted shell.

Check that the forced command is what answers on 2200. This must not print the
output of `id`. Expect it to hang waiting for borg protocol input, or to exit
with a protocol error, and interrupt it if it hangs:

```bash
ssh -i <borg key> -p 2200 taxborn@<helium tailnet ip> id
```

Check which of the two answered on any host. `"none"` means tailscaled answered
and nothing read `authorized_keys`, which is what 22 should say:

```bash
ssh -v taxborn@<tailnet ip> id 2>&1 | grep 'Authenticated to'
```

`borg-repo-base.service` creates `/mnt/hdd/borg` at boot. It runs as `taxborn`
and carries `RequiresMountsFor`, so it does nothing when the external drive is
absent. The drive is mounted `nofail`, and `/mnt/hdd` itself is root-owned
`0755`. Together that means a missing drive fails the backup outright rather
than filling Helium's root filesystem with archives nobody would notice.

## notifications

`client.notify.enable` sends an [ntfy](../ntfy.nix) message to
`ntfy.biscuits.at` after each successful run. It is success only. A failed or
wedged run sends nothing, so a host that stops reporting is the signal, and the
absence is something a person has to notice. borgmatic runs once per
repository, so each host sends one message per copy, labelled `rsync` or
`helium`. Every host uses one write-only token from `secrets/ntfy/token.age`,
so this needs the [ntfy secrets](../../../../secrets/README.md) to exist
before the host rebuilds. Argon's ntfy state under `/var/lib/private/ntfy-sh`
is excluded, since users and tokens come from the secret and the cache is
disposable.

## provisioning a host

The secrets have to exist before the host rebuilds, or activation fails on a
missing `.age` file. So this order is not optional.

### 1. generate key material

```bash
ssh-keygen -t ed25519 -C "borg-<hostname>" -f /tmp/borg_ssh_key -N ""
openssl rand -base64 32 > /tmp/borg_passphrase
```

### 2. encrypt with agenix

`secrets/secrets.nix` already derives rules for every host in its `hosts` list,
so nothing needs adding there for an existing host. Run from `secrets/`, not the
repo root, since agenix looks up the file argument as a rule name verbatim:

```bash
cd secrets
mkdir -p borg/<hostname>
agenix -e borg/<hostname>/passphrase.age < /tmp/borg_passphrase
agenix -e borg/<hostname>/ssh_key.age < /tmp/borg_ssh_key
```

To *replace* a secret rather than edit it, delete the `.age` file first. See
[working with them](../../../../secrets/README.md#working-with-them).

The public key belongs in-repo, because Helium's `server.authorizedKeys` reads
it:

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
`authorized_keys` by round-tripping it over scp. The entry carries a forced
command that confines the key to its own repository, so a new host is never
added bare:

```bash
scp rsync-backup:.ssh/authorized_keys /tmp/rsync_authkeys
printf 'command="borg14 serve --restrict-to-path /data1/home/de4388/borg/%s",restrict %s\n' \
    <hostname> "$(cat /tmp/borg_ssh_key.pub)" >> /tmp/rsync_authkeys
scp /tmp/rsync_authkeys rsync-backup:.ssh/authorized_keys
rm /tmp/rsync_authkeys
```

### 4. create the remote directory

Borg will not create the repository's parent. `borg-repo-base.service` handles
Helium's; rsync.net's restricted shell has no `mkdir`, so use sftp:

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

Run on the host as root, once per repository. This step is interactive because
the first connection to each server would otherwise have to accept its host
key. Both are pinned: Helium's from `keys/root_helium.pub`, and rsync.net's
inline in the backups module, checked against rsync.net's [published
fingerprints](https://www.rsync.net/resources/fingerprints.txt).

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

Start manual backups with `sudo borgmatic create --verbosity 1 --list`, always.
Not `borg create` directly, and not `systemctl start` on the timer's unit. The
borgmatic config is what carries the excludes, the database dumps and the
repository list, and `--verbosity 1 --list` is what shows which files went in
and whether a dump was staged, since a run that silently dropped something
still exits successfully.

```bash
sudo borgmatic create --verbosity 1 --list   # back up now
sudo borgmatic repo-list                     # archives per repository
sudo borgmatic list --archive latest         # files in the latest archive
sudo borgmatic repo-info                     # size, dedup stats
sudo borgmatic check                         # integrity check
sudo borgmatic extract --archive latest --path etc/ssh
sudo systemctl status borgmatic.timer
```

On Helium you can inspect the served repositories directly. Run borg as
`taxborn`, not root. Opening a repository rewrites its `config`, and a root run
leaves it `root:root 0600`, after which the client's forced `borg serve` (which
runs as `taxborn`) fails with `Permission denied: …/config` while the archives
look fine. The NTFS mount's `uid=1000` option used to mask this. If it happens,
`sudo chown -R taxborn:users /mnt/hdd/borg` repairs it, but only for the client
repositories. Leave `/mnt/hdd/borg/helium` root-owned: borgmatic writes it as
root, and its unit's `CapabilityBoundingSet` has `CAP_DAC_READ_SEARCH` but not
`CAP_DAC_OVERRIDE`, so root can read a `taxborn`-owned repository and cannot
write to it. The symptom is `Failed to create/acquire the lock …/lock.exclusive
([Errno 13] Permission denied …)` on Helium's own run, followed by the 6h
timeout. Repair with:

```bash
sudo chown -R root:root /mnt/hdd/borg/helium
sudo borgmatic break-lock --repository helium   # the timeout kill may leave a lock
sudo borgmatic create --verbosity 1 --list --repository helium
```

```bash
sudo -u taxborn borg list /mnt/hdd/borg/argon
sudo -u taxborn borg check --repository-only /mnt/hdd/borg/argon
```

## databases

Copying a database's files while something is writing to them is not a backup.
borg walks them over a stretch of time during which the writes keep coming, so
what lands in the archive is a torn mix of pages whose recoverability depends on
where the commits happened to fall. It usually works, which is the dangerous
part.

So the module excludes the live files, and borgmatic's database hooks put a
logical dump in the archive instead. The dump goes through the database's own
code, which makes it consistent by construction, and it streams into each
archive as borg writes it.

| option | engine | dump | what it excludes |
| --- | --- | --- | --- |
| `postgresqlDumpAll = true` | PostgreSQL | `pg_dumpall` of every database | `/var/lib/postgresql` |
| `sqliteDatabases.<name> = <path>` | SQLite | `sqlite3 <path> .dump` | `<path>*` |

Piper, Vaultwarden, Atuin, Tranquil, Paperless and the Tangled spindle register their
dumps in their service modules whenever the backup client is enabled. Moving one of these services
therefore carries its dump requirement with it. Repository and retention
choices remain with the host. Piper reads its database path from its service
configuration.

Argon takes `pg_dumpall` for Tranquil and Atuin, and SQLite dumps for Piper and
Vaultwarden.
Helium takes the PostgreSQL dump for Paperless. Carbon takes a SQLite dump of
the Tangled spindle's database.

The SQLite exclude carries a trailing glob for a reason: `-wal` and `-shm` sit
beside the database file and hold everything committed since the last
checkpoint. Archiving those out of step with the file they belong to is worse
than archiving neither, because recovery reads the pair and trusts it.

An exclude can silently eat the dump. borgmatic stages dumps on disk and hands
borg the staging path as an extra source, so any exclude covering that path
drops the database from the archive while everything still reports success. The
path depends on how borgmatic was started, `/run/borgmatic` under the packaged
unit (`RuntimeDirectory=borgmatic`) and `/tmp` when run by hand as the restore
test does, so the module removes `/run`, `/tmp`, and `/var/tmp` from the exclude
list on any host taking dumps. They were inert for file selection anyway, since
`paths` never traverses them.

That is not a hypothetical. It is what happened on the first real run here, and
nothing surfaced it except the dump assertion in the restore test. Anything that
adds a database hook later inherits the same problem.

Three details in the module that look like cleanup targets and are not:

- The SQLite hook takes no `username`. borgmatic reads the file directly and the
  unit already runs as root, so there is nothing to switch to. The nixpkgs
  module fills in `sqlite_command` from `pkgs.sqlite` on its own.
- The PostgreSQL dump must be declared as `{ name = "all"; username =
  "postgres"; }` and nothing else. That precise shape, a `username`, no
  `password`, no `pg_dump_command`, is what makes the nixpkgs borgmatic module
  both wrap the dump in `sudo -u postgres` *and* relax its own hardened unit
  (`NoNewPrivileges=false`, `CAP_SETUID`/`CAP_SETGID`) so that switch is
  allowed. Writing the equivalent command by hand opts out of the relaxation and
  the dump dies with `cannot set groups: Operation not permitted`. The
  relaxation is keyed on the PostgreSQL hook alone, so a host taking only SQLite
  dumps keeps the hardened unit, which is fine, and is why the SQLite hook must
  not grow a `username`.
- borgmatic runs one configuration per repository, so the dump is taken once per
  target. That is a little redundant and entirely intentional: each archive is
  independently complete.

Restoring is a separate verb from extracting files:

```bash
sudo borgmatic restore --archive latest                        # all databases
sudo borgmatic restore --archive latest --database tealfm-piper
```

For SQLite this overwrites the live file at its configured path. borgmatic
removes it and replays the dump into a new one, so stop the service first or it
will be holding a database that no longer exists.

This writes to the *live* cluster, so it is not something to run as a test. Tier
1 below asserts the dump is present in the archive without touching the running
database.

## testing restore

A backup is untested until someone restores it. There are three tiers, cheapest
first, and each proves something the tier below it does not.

Everything at once, from a workstation:

```bash
just restore-all
```

Reads `nix eval --json .#restoreCoverage` to cover every enabled backup client,
including Tungsten and Uranium. Tier 1 exercises every configured repository,
including Uranium's local SSD. Tier 2 exercises the remote repositories and
prints an explicit skip reason for Helium's own local repository and Uranium's
local SSD. New remote backends require support in `restore-dr`; new local
repositories require a documented omission in `modules/flake/restore.nix`.

Run with both workstations awake. For a tier 2 rehearsal of the workstation
you are using, repeat that host's `restore-dr` from the other workstation so
it holds none of the target's deployed secrets. The runner continues past
failures and prints a pass/fail summary at the end. It is interactive by nature, a yubikey touch per decrypt and a sudo
prompt per host, so it is not something to put on a timer. The individual
recipes below are what to reach for when one line of that summary says `FAIL`.

### tier 0: key material

```bash
just restore-keys
```

`secrets.nix` encrypts each host's passphrase and SSH key to that host's root
key *plus* my yubikey, and nothing else. If a host is destroyed, the yubikey is
the only thing left that can open its archives. That makes this the
highest-value check in the list, and it costs seconds. Run it from a
workstation, not a server.

The recipes pass the YubiKey identity to `agenix -d` explicitly, for the reason
given in the [secrets guide](../../../../secrets/README.md#working-with-them).
The default identity is `~/.config/age/yubikey-identity.txt`; override it with
`AGE_IDENTITY` if it lives elsewhere. Tier 0 checks decryption exit status, a
nonempty passphrase, and an OpenSSH private-key header before reporting success.

### tier 1: canary round-trip, per host, per repository

```bash
just restore-test argon
```

Writes a timestamp to `/var/lib/backup-canary`, runs `borgmatic create`, then
extracts that one file from *every* configured repository and diffs it against
the original. Repositories are discovered from `/etc/borgmatic.d/`, so a third
target is covered as soon as it deploys.

On a host taking database dumps, the script also asserts that the archive really
contains a dump for every configured database, by name. Both the hooks and the
names are read out of the borgmatic config on disk, so a host that gains an
engine, or another database on an engine it already has, is covered without the
script changing.

Per database rather than per engine, because per engine was the weaker check
that let Argon archive piper and not forgejo: one live sqlite dump kept the
hook looking healthy while the forge's database was absent from every archive.

The canary check alone cannot catch a failed database hook. The live files are
excluded either way, so an archive with no database in it restores files
perfectly and has lost everything the PDS keeps in postgres: every account's
repository, its encrypted signing key, and the firehose sequence. The blobs
under `/var/lib/tranquil-pds/blobs` would come back fine, attached to nothing.

The byte comparison is the assertion, not borg's exit code: an `--path` that
matches nothing still exits 0 and leaves an empty destination. Three related
traps, all handled in the script:

- `--destination` must already exist. borgmatic chdirs into it rather than
  creating it, and fails with `[Errno 2] No such file or directory` if absent.
- extracting into a directory that already holds a previous run collides on
  `etc/static` (`[Errno 17] File exists`), because that symlink points into
  `/nix/store`. Always extract into a freshly emptied directory.
- the dump assertion greps a here-string, never a pipe. `grep -q` exits at the
  first match, which SIGPIPEs a producer still writing an archive listing much
  larger than the pipe buffer; under `set -o pipefail` the pipeline then reports
  141 and the assertion inverts, calling a dump that is present missing. It is
  not a race. borgmatic injects the dump patterns at the head of the pattern
  list, so the match is always in the first few lines of a listing with the
  whole of `/home`, `/var/lib`, and `/etc` still to come. `just restore-all`
  had the same shape in its summary, where the inversion would have hidden
  failures rather than invented them.

Note that on Helium the `helium` repository is a local path, so that iteration
exercises no SSH at all. Helium's role as a *server* is only covered when a
client runs tier 1. Run it on Argon or Carbon to exercise the ssh path, the host
key pin, and the `authorized_keys` entry.

The scheduled integrity checks can also be forced on demand, independent of
their `frequency`. This reads the whole repository and is slow, which is why it
is not part of `restore-test`:

```bash
sudo borgmatic check --repository rsync --force
```

### tier 2: disaster rehearsal

Tier 1 runs on a healthy host that already has its own secrets mounted, which
is not the scenario any of this insures against. Tier 2 restores a host's data
from a machine that holds none of it, using only the yubikey:

```bash
just restore-dr argon                    # off-site copy, on rsync.net
just restore-dr argon helium             # second copy, on Helium's drive
just restore-dr argon rsync helium       # both, on one pair of yubikey touches
```

Validates the requested host and repositories against `restoreCoverage` before
decryption. Repository URLs and remote Borg executables come from that plan,
so changing a backup destination also changes the rehearsal destination.
Requests containing only local repositories print their skip reasons without
decrypting anything.

Decrypts that host's key material into a unique directory under
`$XDG_RUNTIME_DIR` (normally `/run/user/$UID`, tmpfs, `0700`, shredded
on exit), then for each named repository pulls the latest archive name, extracts
the canary, and compares it against the live host if it is still reachable.
Passing both repositories means the host is genuinely recoverable from either
copy with nothing but the yubikey.

The decryption happens once regardless of how many repositories are named, since
each `agenix -d` costs a yubikey touch. Naming both is strictly cheaper than two
invocations.

Reaching the Helium repository from a third machine goes over Tailscale SSH,
which authorises by tailnet identity and never reads `authorized_keys`, so the
decrypted borg key is not what opens the connection. What it proves is the half
a lost host actually needs: that the archive decrypts with the passphrase that
host's key file carries. Helium's full repository URL comes from the evaluated
backup configuration, including its username, tailnet address and directory.

`just restore-dr helium helium` is therefore impossible and exits with a note
pointing elsewhere. Helium reaches its own repository by local path and holds no
key entry for itself. Verify that one on the host:

```bash
sudo borg list /mnt/hdd/borg/helium
```

Helium's own repository is the exception to running as `taxborn`: borgmatic
writes it as root over a local path, and nothing serves it over ssh.

Doing it by hand, three things bite:

- `repo::` takes the archive *name*, not the ID. `borg list` prints name,
  timestamp, and ID; copying the wrong column gives `Archive … does not exist`.
  Let `--last 1 --format '{archive}{NL}'` pick it instead.
- `ssh <host> <command>` fails with `Cannot execute command-line and remote
  command` wherever the SSH client config sets `RemoteCommand`. Add
  `-o RemoteCommand=none`, the same workaround `just update` uses for
  `nixos-rebuild`.
- that same config sets `RequestTTY yes`, which allocates a pty whenever ssh
  itself has a local tty, and a pty translates LF to CRLF. Reading a file that
  way returns a trailing `\r` that command substitution does *not* strip, so a
  byte comparison fails against content that is visibly identical. Pass
  `-o RequestTTY=no` *and* pipe through `tr -d '\r'`: the option loses to an
  explicit `-t`/`-tt`, so neither alone is sufficient. This only reproduces from
  an interactive shell, which makes it easy to miss when testing from a script.

### what a real restore actually looks like

Not `borg extract` with no path argument. Most of a host's `/etc` is symlinks
into `/nix/store` (`etc/static` among them), and a recovered host gets that
directory regenerated by rebuilding from the flake. Extracting the archive's
`/etc` over it fights nix rather than helping it. The order is:

1. rebuild the host from the flake, which restores `/etc`, `/nix`, and every
   service's configuration
2. restore only the state the flake cannot reproduce: `/var/lib` for service
   data, `/home` for everything else
3. run that step as root with `--numeric-ids`, or ownership and modes come back
   wrong

Tiers 1 and 2 extract a single small file for speed, which deliberately does
*not* verify ownership. Once a service with real state exists, do one `sudo`
restore of its `/var/lib` directory to confirm permissions survive the trip.

## options

### `myNixOS.services.backups.client`

| option | type | default | description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | enable the borgmatic client |
| `paths` | list of str | `[ "/home" "/var/lib" "/etc" ]` | directories to back up |
| `extraExcludes` | list of str | `[ ]` | exclude patterns on top of the defaults |
| `desktopExcludes` | bool | `false` | also exclude a desktop `$HOME`'s caches and re-downloadable data |
| `repositories` | attrsOf { path, label, remotePath? } | rsync.net + Helium | targets to back up to |
| `notify.enable` | bool | `false` | send an ntfy message after each successful run |
| `notify.topic` | str | `"backups"` | topic the messages go to; must match the ACL in `secrets/ntfy.age` |
| `retention.keepDaily` | int | `7` | daily archives to keep |
| `retention.keepWeekly` | int | `4` | weekly archives to keep |
| `retention.keepMonthly` | int | `6` | monthly archives to keep |
| `retention.keepYearly` | int | `1` | yearly archives to keep |

A directory containing `.nobackup` is skipped.

`desktopExcludes` exists because the default excludes were written against
servers, where `/home` holds a shell history and little else. Backing up the
same three directories on a workstation ships browser caches, Electron app
caches (which live under `.config`, not `.cache`, so they survive the obvious
pattern), Steam runtimes, and every virtualenv and direnv on the machine. None
of it dedups well between runs and none of it is worth restoring.

It is off by default and *not* implied by `profiles.workstation`. Deciding what
under `/home` is disposable is a judgement about the host, and getting it wrong
drops real data silently. `~/Downloads` is left in the archive for that reason.

Snapper's `.snapshots` directories need no entry here. `profiles/btrfs` derives
an exclude for every subvolume in its `snapshotSubvolumes`, so a backup path
containing one does not quietly archive the whole timeline alongside the live
data.

### `myNixOS.services.backups.server`

| option | type | default | description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | serve borg repositories over SSH |
| `authorizedKeys` | attrsOf str | `{ }` | client hostname -> that host's borg SSH public key |

## enabling on a host

```nix
myNixOS.services.backups.client = {
  enable = true;
  extraExcludes = [ "/var/lib/containers" ];
};
```

Both repositories are added automatically,
`ssh://de4388@de4388.rsync.net/./borg/<hostname>` and
`ssh://taxborn@<helium tailnet IP>:2200//mnt/hdd/borg/<hostname>`. Naming an
attribute replaces that target:

```nix
myNixOS.services.backups.client.repositories.rsync.path =
  lib.mkForce "ssh://de4388@de4388.rsync.net/./borg/<hostname>-alt";
```
