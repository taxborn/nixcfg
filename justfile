# Identity used to decrypt secrets locally. `agenix -d` only tries the default
# ssh keys on its own; `age.identityPaths` is system-level and does not apply.
age_identity := env("AGE_IDENTITY", "~/.config/age/yubikey-identity.txt")

# Update a NixOS system (local by default, or HOST for a remote deploy)
update host="":
    #!/usr/bin/env bash
    if [ -z "{{host}}" ]; then
        sudo nixos-rebuild switch --flake .
    else
        NIX_SSHOPTS="-o RemoteCommand=none -o RequestTTY=no" \
            nixos-rebuild switch --flake .#{{host}} --target-host {{host}} --ask-sudo-password
    fi

# Remove all old nix generations
clean:
    sudo nix-collect-garbage -d

# Reclaim a runner's shared CI nix store (HOST must be idle; see README)
runner-gc host:
    #!/usr/bin/env bash
    set -euo pipefail

    attr=".#nixosConfigurations.{{host}}.config.myNixOS.services.forgejo.runner"
    volume=$(nix eval --raw "$attr.storeVolume")
    image=$(nix eval --raw "$attr.nixImage")

    # Stopping the runner is the whole point rather than an inconvenience: a
    # collection racing three concurrent jobs is exactly what the pid-namespace
    # note in the runner module says not to do. It also means this can block for
    # as long as `shutdown_timeout` if a job is mid-flight — run it when the
    # forge is quiet.
    #
    # Rootless Podman is reached through the runner user's own runtime
    # directory, which exists between boots only because that user lingers.
    ssh -t -o RemoteCommand=none {{host}} "
        set -euo pipefail
        sudo systemctl stop forgejo-runner
        trap 'sudo systemctl start forgejo-runner' EXIT
        sudo -u forgejo-runner env XDG_RUNTIME_DIR=/run/user/\$(id -u forgejo-runner) \
            podman run --rm -v '$volume:/nix' '$image' \
            nix --extra-experimental-features nix-command store gc --print-live
    "

# Verify the yubikey can decrypt every host's borg secrets (restore tier 0)
restore-keys:
    #!/usr/bin/env bash
    set -euo pipefail
    cd secrets
    for dir in borg/*/; do
        host=$(basename "$dir")
        printf '%-10s passphrase %4s bytes | key %s\n' \
            "$host" \
            "$(agenix -d "borg/$host/passphrase.age" -i {{age_identity}} | wc -c)" \
            "$(agenix -d "borg/$host/ssh_key.age" -i {{age_identity}} | head -1)"
    done

# Canary round-trip through every repository on HOST (restore tier 1)
restore-test host:
    #!/usr/bin/env bash
    set -euo pipefail
    # Sent as a command argument rather than on stdin so the pty that `-t`
    # allocates for the sudo prompt cannot mangle the script.
    payload=$(base64 -w0 <scripts/backup-restore-test.sh)
    ssh -t -o RemoteCommand=none {{host}} \
        "echo $payload | base64 -d | sudo bash"

# Restore HOST's canary from each REPO using only the yubikey (restore tier 2)
restore-dr host *repos="rsync":
    #!/usr/bin/env bash
    # No -e: a failing repository must not skip the ones after it.
    set -uo pipefail
    umask 077
    root=$PWD
    key=/run/user/$(id -u)/borg-dr-key
    pass=/run/user/$(id -u)/borg-dr-pass
    trap 'shred -u "$key" "$pass" 2>/dev/null || true' EXIT

    # Decrypted once for every repository, because each call costs a yubikey
    # touch. agenix resolves its argument as a rule name verbatim, so this must
    # run from secrets/. Check both: a failed decrypt still leaves an empty file
    # behind, and every borg error downstream would then be a red herring.
    for secret in ssh_key passphrase; do
        case "$secret" in
            ssh_key) out=$key ;;
            passphrase) out=$pass ;;
        esac
        if ! (cd secrets && agenix -d "borg/{{host}}/$secret.age" -i {{age_identity}}) >"$out" \
                || [ ! -s "$out" ]; then
            echo "FAIL — could not decrypt {{host}}'s $secret (wrong PIN?)" >&2
            exit 1
        fi
    done

    helium_ip=""
    rc=0

    for repo in {{repos}}; do
        echo "== {{host}} -> $repo"
        case "$repo" in
            rsync)
                repo_url="ssh://de4388@de4388.rsync.net/./borg/{{host}}"
                remote=(--remote-path borg14)
                ;;
            helium)
                if [ "{{host}}" = "helium" ]; then
                    echo "SKIP — helium reaches its own repository by local path, so no"
                    echo "key authorizes it remotely. Covered by \`just restore-test helium\`."
                    continue
                fi
                # This works only because the forced command pinned to {{host}}'s
                # key restricts it to exactly this path. Address and port both
                # come from the flake so they cannot drift from the modules —
                # and the port is not 22 precisely so that the forced command is
                # applied at all (Tailscale SSH would bypass it on 22).
                if [ -z "$helium_ip" ]; then
                    helium_ip=$(cd "$root" && nix eval --raw \
                        .#nixosConfigurations.helium.config.mySnippets.tailnet.tailscaleIPs.helium)
                    helium_port=$(cd "$root" && nix eval \
                        .#nixosConfigurations.helium.config.myNixOS.services.backups.server.sshPort)
                fi
                # basePath is absolute, hence the doubled slash after the host.
                repo_url="ssh://taxborn@$helium_ip:$helium_port//mnt/hdd/borg/{{host}}"
                remote=()
                ;;
            *)
                echo "FAIL — unknown repository '$repo' (expected: rsync, helium)" >&2
                rc=1
                continue
                ;;
        esac

        dest=$(mktemp -d)
        if ! archive=$(nix shell nixpkgs#borgbackup -c env \
                BORG_PASSCOMMAND="cat $pass" BORG_RSH="ssh -i $key" \
                borg list "${remote[@]}" --last 1 --format '{archive}{NL}' "$repo_url"); then
            echo "FAIL $repo — could not list the repository"
            rc=1
            continue
        fi
        echo "latest archive: $archive"

        if ! (cd "$dest" && nix shell nixpkgs#borgbackup -c env \
                BORG_PASSCOMMAND="cat $pass" BORG_RSH="ssh -i $key" \
                borg extract "${remote[@]}" "$repo_url::$archive" var/lib/backup-canary); then
            echo "FAIL $repo — extract failed"
            rc=1
            continue
        fi

        restored=$(cat "$dest/var/lib/backup-canary" 2>/dev/null || true)
        if [ -z "$restored" ]; then
            echo "FAIL $repo — nothing restored"
            rc=1
            continue
        fi
        echo "restored: $restored"

        # RequestTTY=no matters as much as RemoteCommand=none: the ssh config
        # sets both, and reading through a pty translates LF to CRLF, leaving a
        # trailing \r that command substitution does not strip. tr is the belt
        # to that braces, in case the config changes again.
        if live=$(ssh -o RemoteCommand=none -o RequestTTY=no -o BatchMode=yes \
                {{host}} cat /var/lib/backup-canary 2>/dev/null | tr -d '\r'); then
            if [ "$live" = "$restored" ]; then
                echo "PASS $repo — matches {{host}}"
            else
                echo "FAIL $repo — {{host}} has: $live"
                rc=1
            fi
        else
            echo "PASS $repo — {{host}} unreachable, content above is the only assertion"
        fi
        rm -rf "$dest"
        echo
    done
    exit $rc

# Run every restore test across every host and repository (tiers 0-2)
restore-all:
    #!/usr/bin/env bash
    # Interactive by nature: expect a yubikey touch per decrypt and a sudo
    # prompt per host. Nothing here is safe to run unattended.
    set -uo pipefail
    declare -a results

    run() {
        local label="$1"; shift
        echo
        echo "############ $label"
        if "$@"; then results+=("PASS  $label"); else results+=("FAIL  $label"); fi
    }

    run "tier 0  key material, all hosts"      just restore-keys
    run "tier 1  argon  -> rsync + helium"     just restore-test argon
    run "tier 1  carbon -> rsync + helium"     just restore-test carbon
    run "tier 1  helium -> rsync + local"      just restore-test helium
    run "tier 2  argon  from tungsten"         just restore-dr argon rsync helium
    run "tier 2  carbon from tungsten"         just restore-dr carbon rsync helium
    run "tier 2  helium from tungsten"         just restore-dr helium rsync

    echo
    echo "############ summary"
    printf '%s\n' "${results[@]}"

    # Deliberately not `printf ... | grep -q '^FAIL'`: grep exits at the first
    # match and SIGPIPEs the producer, which under `pipefail` flips the status
    # and lets a run with failures exit 0. The summary is short enough that it
    # would not bite today, but it is the same trap that made the dump
    # assertion in scripts/backup-restore-test.sh report false failures.
    for result in "${results[@]}"; do
        [[ $result == FAIL* ]] && exit 1
    done
    exit 0
