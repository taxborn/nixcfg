#!/usr/bin/env bash
# No -e: a failing repository must not skip the ones after it.
set -uo pipefail
identity=$1
host=$2
shift 2
repos=("$@")

# Validate every requested destination before spending a YubiKey touch.
if ! coverage=$(nix eval --json .#restoreCoverage); then
    exit 1
fi
if ! plan=$(jq -ce --arg host "$host" '.[$host] // error("unknown backup host")' <<<"$coverage"); then
    exit 1
fi
remote_count=0
for repo in "${repos[@]}"; do
    if ! entry=$(jq -ce --arg repo "$repo" '.[$repo] // error("unknown repository")' <<<"$plan"); then
        exit 1
    fi
    if [ "$(jq -r '.tier2' <<<"$entry")" = true ]; then
        remote_count=$((remote_count + 1))
    else
        echo "SKIP $host/$repo: $(jq -r '.reason' <<<"$entry")"
    fi
done
((remote_count > 0)) || exit 0

umask 077
scratch=$(mktemp -d "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/borg-dr.XXXXXXXX") || exit 1
key=$scratch/key
pass=$scratch/pass
trap 'shred -u "$key" "$pass" 2>/dev/null || true; rm -rf "$scratch"' EXIT

# Decrypted once for all repositories, because each call costs a yubikey
# touch. agenix resolves its argument as a rule name verbatim, so this must
# run from secrets/. Check both: a failed decrypt still leaves an empty file
# behind, and every borg error downstream would then be a red herring.
for secret in ssh_key passphrase; do
    case "$secret" in
        ssh_key) out=$key ;;
        passphrase) out=$pass ;;
    esac
    if ! (cd secrets && agenix -d "borg/$host/$secret.age" -i "$identity") >"$out" \
            || [ ! -s "$out" ]; then
        echo "FAIL: could not decrypt $host's $secret (wrong PIN?)" >&2
        exit 1
    fi
done

rc=0

for repo in "${repos[@]}"; do
    entry=$(jq -c --arg repo "$repo" '.[$repo]' <<<"$plan")
    [ "$(jq -r '.tier2' <<<"$entry")" = true ] || continue
    echo "== $host -> $repo"
    repo_url=$(jq -r '.path' <<<"$entry")
    remote_path=$(jq -r '.remotePath // empty' <<<"$entry")
    remote=()
    [ -z "$remote_path" ] || remote=(--remote-path "$remote_path")

    # Helium uses Tailscale SSH on 22, which skips authorized_keys. The
    # operator's tailnet identity authorizes this connection, not the decrypted
    # borg key. This tests that a lost host's passphrase opens its archive.
    # Confining keys with forced commands would require a separate sshd port.
    dest=$(mktemp -d "$scratch/extract.XXXXXXXX") || { rc=1; continue; }
    if ! archive=$(nix shell nixpkgs#borgbackup -c env \
            BORG_PASSCOMMAND="cat $pass" BORG_RSH="ssh -i $key" \
            borg list "${remote[@]}" --last 1 --format '{archive}{NL}' "$repo_url"); then
        echo "FAIL $repo: could not list the repository"
        rc=1
        continue
    fi
    echo "latest archive: $archive"

    if ! (cd "$dest" && nix shell nixpkgs#borgbackup -c env \
            BORG_PASSCOMMAND="cat $pass" BORG_RSH="ssh -i $key" \
            borg extract "${remote[@]}" "$repo_url::$archive" var/lib/backup-canary); then
        echo "FAIL $repo: extract failed"
        rc=1
        continue
    fi

    restored=$(cat "$dest/var/lib/backup-canary" 2>/dev/null || true)
    if [ -z "$restored" ]; then
        echo "FAIL $repo: nothing restored"
        rc=1
        continue
    fi
    echo "restored: $restored"

    # RequestTTY=no matters as much as RemoteCommand=none: the ssh config
    # sets both, and reading through a pty translates LF to CRLF, leaving a
    # trailing \r that command substitution does not strip. tr is the belt
    # to that braces, in case the config changes again.
    if live=$(ssh -o RemoteCommand=none -o RequestTTY=no -o BatchMode=yes \
            "$host" cat /var/lib/backup-canary 2>/dev/null | tr -d '\r'); then
        if [ "$live" = "$restored" ]; then
            echo "PASS $repo: matches $host"
        else
            echo "FAIL $repo: $host has: $live"
            rc=1
        fi
    else
        echo "PASS $repo: $host unreachable, content above is the only assertion"
    fi
    rm -rf "$dest"
    echo
done
exit $rc
