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
