#!/usr/bin/env bash
# Compare rsync.net's authorized_keys with what the host roster says it should
# hold. Nothing in the repo can enforce that file, because it lives on
# rsync.net and is edited by hand, and a host added without its forced command
# is unrestricted there with no error to say so.
#
#   rsync-authorized-keys.sh expected [REPO_ROOT]
#   rsync-authorized-keys.sh check AUTHORIZED_KEYS_FILE [REPO_ROOT]
#   rsync-authorized-keys.sh fetch [REPO_ROOT]
#
# `expected` and `check` are offline, which is what the test drives. Only
# `fetch` touches the network.
set -euo pipefail

account=${RSYNC_NET_ACCOUNT:-de4388}
# The directory the forced command is confined under. It is the same literal
# the provisioning steps in the backups README use.
base=/data1/home/$account/borg

# One entry per borg key, in the exact shape the README tells a person to add.
# The roster is the secrets/borg directories, the same set restore-keys walks.
expected() {
    local root=$1 dir host key
    for dir in "$root"/secrets/borg/*/; do
        host=$(basename "$dir")
        key=$(<"$dir/ssh_key.pub")
        printf 'command="borg14 serve --restrict-to-path %s/%s",restrict %s\n' \
            "$base" "$host" "$key"
    done
}

# Reduce an entry to "<options>|<key type> <key blob>", dropping the trailing
# comment, which is a label and not part of what sshd matches on.
normalize() {
    sed -E \
        -e '/^[[:space:]]*(#|$)/d' \
        -e 's/^(command="[^"]*"[^ ]*) +(ssh-[^ ]+ [^ ]+).*$/\1|\2/' \
        -e 's/^(ssh-[^ ]+ [^ ]+).*$/|\1/'
}

check() {
    local file=$1 root=$2 want have operator missing extra rc=0
    want=$(expected "$root" | normalize | sort -u)
    # The operator's own yubikey entry stays bare by design, so it is not drift.
    operator=$(normalize <"$root/keys/yubikey.pub")
    have=$(normalize <"$file" | grep -vxF -e "$operator" | sort -u || true)

    missing=$(comm -23 <(printf '%s\n' "$want") <(printf '%s\n' "$have"))
    extra=$(comm -13 <(printf '%s\n' "$want") <(printf '%s\n' "$have"))

    if [[ -n $missing ]]; then
        echo "MISSING (expected, absent or without its forced command):" >&2
        sed 's/^/  /' <<<"$missing" >&2
        rc=1
    fi
    if [[ -n $extra ]]; then
        echo "UNEXPECTED (not in the roster, or wrong confinement):" >&2
        sed 's/^/  /' <<<"$extra" >&2
        rc=1
    fi
    if ((rc == 0)); then
        echo "ok: authorized_keys matches the roster"
    fi
    return "$rc"
}

cmd=${1:-}
case $cmd in
expected)
    expected "${2:-.}"
    ;;
check)
    check "${2:?authorized_keys file required}" "${3:-.}"
    ;;
fetch)
    tmp=$(mktemp)
    trap 'rm -f "$tmp"' EXIT
    # Pulled with scp for the same reason the provisioning steps use it: the
    # restricted shell has no cat. Needs the operator's yubikey entry.
    scp "$account@$account.rsync.net:.ssh/authorized_keys" "$tmp"
    check "$tmp" "${2:-.}"
    ;;
*)
    echo "usage: $0 expected|check FILE|fetch [REPO_ROOT]" >&2
    exit 2
    ;;
esac
