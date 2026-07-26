# borg/borgmatic backups

borgmatic client module with agenix-managed secrets. Deliberately minimal: one
target (rsync.net), no database hooks, no server mode. Those come back as the
hosts that need them exist — see [TODO.md](../../../../TODO.md).

## architecture

- borgmatic runs from its packaged systemd timer (daily) on each client
- one borgmatic configuration per repository, because `remote_path` is a
  per-config setting and rsync.net needs `borg14`; a single timer run walks all
  of them
- repositories live at `~/borg/<hostname>` on rsync.net
- passphrase and SSH key are per-host agenix secrets, readable only by that
  host's key (and my yubikey)

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

Keep the public key in-repo — the borg server module will want it once Helium
exists:

```bash
cp /tmp/borg_ssh_key.pub borg/<hostname>/ssh_key.pub
```

### 3. authorize the key on rsync.net

rsync.net's restricted shell blocks redirection (`>`/`>>`), so edit
`authorized_keys` by round-tripping it over scp:

```bash
scp rsync-backup:.ssh/authorized_keys /tmp/rsync_authkeys
cat /tmp/borg_ssh_key.pub >> /tmp/rsync_authkeys
scp /tmp/rsync_authkeys rsync-backup:.ssh/authorized_keys
rm /tmp/rsync_authkeys
```

### 4. create the remote directory

Borg will not create the repository's parent, and the restricted shell has no
`mkdir` — use sftp:

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

### 6. initialize the repository

Run on the host as root. The first connection has to accept rsync.net's host
key, which is why this step is interactive.

```bash
sudo borgmatic repo-create --encryption repokey-blake2
sudo borgmatic create --verbosity 1 --list
```

### 7. clean up

```bash
shred -u /tmp/borg_ssh_key /tmp/borg_passphrase
rm /tmp/borg_ssh_key.pub
```

## operating

Run as root; configs live in `/etc/borgmatic.d/`. Subcommands are borgmatic 2.x.

```bash
sudo borgmatic create --verbosity 1 --list   # back up now
sudo borgmatic repo-list                     # archives per repository
sudo borgmatic list --archive latest         # files in the latest archive
sudo borgmatic repo-info                     # size, dedup stats
sudo borgmatic check                         # integrity check
sudo borgmatic extract --archive latest --path etc/ssh
sudo systemctl status borgmatic.timer
```

## options

All under `myNixOS.services.backups.client`.

| option | type | default | description |
|--------|------|---------|-------------|
| `enable` | bool | `false` | enable the borgmatic client |
| `paths` | list of str | `[ "/home" "/var/lib" "/etc" ]` | directories to back up |
| `extraExcludes` | list of str | `[ ]` | exclude patterns on top of the defaults |
| `repositories` | attrsOf { path, label, remotePath? } | rsync.net entry | targets to back up to |
| `retention.keepDaily` | int | `7` | daily archives to keep |
| `retention.keepWeekly` | int | `4` | weekly archives to keep |
| `retention.keepMonthly` | int | `6` | monthly archives to keep |
| `retention.keepYearly` | int | `1` | yearly archives to keep |

A directory containing `.nobackup` is skipped.

## enabling on a host

```nix
myNixOS.services.backups.client = {
  enable = true;
  extraExcludes = [ "/var/lib/containers" ];
};
```

The rsync.net repository is added automatically at
`ssh://de4388@de4388.rsync.net/./borg/<hostname>`. Adding a second target later
is additive:

```nix
myNixOS.services.backups.client.repositories.helium = {
  path = "ssh://taxborn@${config.mySnippets.tailnet.tailscaleIPs.helium}//mnt/hdd/borg/argon";
  label = "helium";
};
```
