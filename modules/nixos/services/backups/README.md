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
nothing but serve that one repository — a compromised host can neither read nor
delete another host's archives. `restrict` additionally drops pty allocation,
port forwarding, agent forwarding, and user rc.

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

The byte comparison is the assertion, not borg's exit code: an `--path` that
matches nothing still exits 0 and leaves an empty destination. Two related
traps, both baked into the script:

- `--destination` must already exist — borgmatic chdirs into it rather than
  creating it, and fails with `[Errno 2] No such file or directory` if absent.
- extracting into a directory that already holds a previous run collides on
  `etc/static` (`[Errno 17] File exists`), because that symlink points into
  `/nix/store`. Always extract into a freshly emptied directory.

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
`--restrict-to-path` confines it to exactly the repository being read. Helium's
tailnet address comes from `nix eval` against `mySnippets.tailnet` rather than a
literal, so the recipe cannot drift from the module.

`just restore-dr helium helium` is therefore impossible and exits with a note
pointing elsewhere — Helium reaches its own repository by local path and holds
no key entry for itself (`hosts/helium/default.nix:16-18`). Verify that one on
the host:

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
