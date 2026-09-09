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

# Deploy the current tip of braxton.is to Carbon
deploy-site:
    #!/usr/bin/env bash
    set -euo pipefail

    # The whole deploy is this lock bump: the revision pinned here is the
    # revision Carbon serves, so the site rolls back the way anything else on
    # these machines does, by rolling back a generation.
    nix flake update braxton-is

    # Guarded so re-running when the site has not moved redeploys rather than
    # failing on an empty commit.
    if ! git diff --quiet flake.lock; then
        git commit -m "chore(site): bump braxton.is" flake.lock
    fi

    just update carbon

# Run every pre-commit hook over the whole tree, not just the staged files
check:
    nix develop --command pre-commit run --all-files

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
