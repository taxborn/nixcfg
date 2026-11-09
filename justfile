# Identity used to decrypt secrets locally. `agenix -d` only tries the default
# ssh keys on its own; `age.identityPaths` is system-level and does not apply.
age_identity := env("AGE_IDENTITY", "~/.config/age/yubikey-identity.txt")

# Update a NixOS system (local by default, or HOST for a remote deploy)
update host="":
    #!/usr/bin/env bash
    if [ -z "{{ host }}" ]; then
        sudo nixos-rebuild switch --flake .
    else
        # Every host alias in the ssh config opens tmux on a pty, which is what
        # makes an interactive `ssh <host>` worth having and what makes it
        # useless here. nixos-rebuild runs its own commands and reads their
        # output, so both settings are overridden per-invocation rather than
        # dropped from the config.
        NIX_SSHOPTS="-o RemoteCommand=none -o RequestTTY=no" \
            nixos-rebuild switch --flake .#{{ host }} --target-host {{ host }} --ask-sudo-password
    fi

# Run every pre-commit hook over the whole tree, not just the staged files
check:
    nix develop --command pre-commit run --all-files

# Diff caddy.nix's Cloudflare ranges against Cloudflare's published lists
check-cloudflare-ips:
    #!/usr/bin/env bash
    set -euo pipefail
    # Only the quoted CIDRs inside the two range lists, so other strings in the
    # file cannot leak into the comparison.
    ours=$(awk '/cloudflare(IPv4|IPv6)Ranges = \[/ {on=1; next} on && /\];/ {on=0} on {gsub(/[ "]/, ""); print}' \
        modules/nixos/services/caddy.nix | sort)
    theirs=$( { curl -fsS https://www.cloudflare.com/ips-v4; echo; curl -fsS https://www.cloudflare.com/ips-v6; } \
        | sed '/^$/d' | sort)
    if [ -z "$ours" ] || [ -z "$theirs" ]; then
        echo "could not read one of the two lists" >&2
        exit 2
    fi
    if diff=$(diff <(echo "$ours") <(echo "$theirs")); then
        echo "caddy.nix matches Cloudflare's published ranges"
    else
        echo "drift (< caddy.nix, > Cloudflare):"
        echo "$diff"
        exit 1
    fi

# Remove all old nix generations
clean:
    sudo nix-collect-garbage -d

# Verify the yubikey can decrypt every host's borg secrets (restore tier 0)
restore-keys:
    bash scripts/restore-keys.sh {{ age_identity }}

# Canary round-trip through every repository on HOST (restore tier 1)
restore-test host:
    #!/usr/bin/env bash
    set -euo pipefail
    # Sent as a command argument rather than on stdin so the pty that `-t`
    # allocates for the sudo prompt cannot mangle the script.
    payload=$(base64 -w0 <scripts/backup-restore-test.sh)
    ssh -t -o RemoteCommand=none {{ host }} \
        "echo $payload | base64 -d | sudo bash"

# Restore HOST's canary from each REPO using only the yubikey (restore tier 2)
[positional-arguments]
restore-dr host *repos="rsync":
    bash scripts/restore-dr.sh {{ age_identity }} "$@"

# Run every restore test across the evaluated backup-client roster (tiers 0-2)
restore-all:
    bash scripts/restore-all.sh

# Diff rsync.net's authorized_keys against the host roster (needs the yubikey)
rsync-keys-check:
    bash scripts/rsync-authorized-keys.sh fetch

# Offline test of the expected-entries generation behind rsync-keys-check
rsync-keys-test:
    bash scripts/rsync-authorized-keys-test.sh
