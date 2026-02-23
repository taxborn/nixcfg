# borg/borgmatic backups

borgmatic-based backup module supporting multiple repositories per host, agenix-managed secrets, and a borg server mode for helium.

## architecture

- each host runs borgmatic as a systemd timer (daily)
- each repository gets its own borgmatic configuration (required because rsync.net uses `remote_path = "borg14"`)
- borgmatic processes all configs in a single timer run
- helium-01 acts as a borg server via restricted SSH authorized_keys on the taxborn user

## provisioning a new host

### 1. generate SSH keypair

```bash
ssh-keygen -t ed25519 -C "borg-<hostname>" -f /tmp/borg_ssh_key -N ""
```

### 2. generate passphrase

```bash
openssl rand -base64 32 > /tmp/borg_passphrase
```

### 3. encrypt with agenix

from the secrets repo:

```bash
mkdir -p borg/<hostname>

# encrypt passphrase
agenix -e borg/<hostname>/passphrase.age < /tmp/borg_passphrase

# encrypt private key
agenix -e borg/<hostname>/ssh_key.age < /tmp/borg_ssh_key
```

copy the public key for later:

```bash
cp /tmp/borg_ssh_key.pub borg/<hostname>/ssh_key.pub
```

### 4. add secrets.nix entries

add to `secrets/secrets.nix`:

```nix
"borg/<hostname>/passphrase.age".publicKeys = [hostKey] ++ userKeys;
"borg/<hostname>/ssh_key.age".publicKeys = [hostKey] ++ userKeys;
```

where `hostKey` is the target host's root SSH public key.

### 5. add public key to remotes

**rsync.net:**

```bash
scp /tmp/borg_ssh_key.pub de4388@de4388.rsync.net:.ssh/authorized_keys_borg_<hostname>
# then SSH in and append to authorized_keys, or use rsync.net's key management
```

**helium-01:** add the public key to helium's `myNixOS.services.backups.server.authorizedKeys.<hostname>`.

### 6. initialize borg repos

**rsync.net:**

```bash
BORG_RSH="ssh -i /tmp/borg_ssh_key" BORG_PASSPHRASE="$(cat /tmp/borg_passphrase)" \
  BORG_REMOTE_PATH=borg14 \
  borg init --encryption=repokey-blake2 \
  ssh://de4388@de4388.rsync.net/./borg-repos/<hostname>
```

**helium:**

```bash
BORG_RSH="ssh -i /tmp/borg_ssh_key" BORG_PASSPHRASE="$(cat /tmp/borg_passphrase)" \
  borg init --encryption=repokey-blake2 \
  ssh://taxborn@100.64.1.0//mnt/hdd/borg-repos/<hostname>
```

### 7. clean up temp files

```bash
shred -u /tmp/borg_ssh_key /tmp/borg_passphrase
rm /tmp/borg_ssh_key.pub
```

### 8. rebuild

```bash
sudo nixos-rebuild switch --flake .#<hostname>
```

## borgmatic commands

run as root (borgmatic configs are in `/etc/borgmatic.d/`):

```bash
# list all archives across all configs
sudo borgmatic list

# create a backup now
sudo borgmatic create --verbosity 1

# show repo info (size, encryption, etc.)
sudo borgmatic info

# check repository integrity
sudo borgmatic check

# extract files from latest archive
sudo borgmatic extract --path /home/taxborn/documents

# run against a specific config only
sudo borgmatic -c /etc/borgmatic.d/rsync.yaml list
```

## module options

### client

| option | type | default | description |
|--------|------|---------|-------------|
| `client.enable` | bool | false | enable borgmatic backup client |
| `client.paths` | list of str | `["/home" "/var/lib" "/etc"]` | directories to back up |
| `client.desktopExcludes` | bool | false | exclude Steam, node_modules, cargo, caches |
| `client.extraExcludes` | list of str | `[]` | additional exclude patterns |
| `client.repositories` | attrsOf { path, label, remotePath? } | `{}` | named borg repositories |
| `client.retention.keepDaily` | int | 7 | daily archives to keep |
| `client.retention.keepWeekly` | int | 4 | weekly archives to keep |
| `client.retention.keepMonthly` | int | 6 | monthly archives to keep |
| `client.retention.keepYearly` | int | 1 | yearly archives to keep |

### server

| option | type | default | description |
|--------|------|---------|-------------|
| `server.enable` | bool | false | enable borg server (SSH keys) |
| `server.basePath` | str | `/mnt/hdd/borg-repos` | base directory for repos |
| `server.user` | str | `taxborn` | SSH user for borg access |
| `server.authorizedKeys` | attrsOf str | `{}` | hostname -> SSH public key |
