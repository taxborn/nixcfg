#!/usr/bin/env bash
# Offline test for rsync-authorized-keys.sh against the real roster.
set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
tool=$here/rsync-authorized-keys.sh
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
    echo "FAIL: $1" >&2
    exit 1
}

n=$(find "$root/secrets/borg" -name ssh_key.pub | wc -l)
"$tool" expected "$root" >"$tmp/good"
[[ $(wc -l <"$tmp/good") -eq $n ]] || fail "entry count differs from roster ($n)"
if grep -vq '^command="borg14 serve --restrict-to-path /data1/home/de4388/borg/[a-z]*",restrict ssh-ed25519 ' "$tmp/good"; then
    fail "malformed expected entry"
fi

# The operator's bare yubikey entry plus relabelled comments must pass.
{
    cat "$root/keys/yubikey.pub"
    sed 's/ borg-[a-z]*$/ renamed/' "$tmp/good"
} >"$tmp/ok"
"$tool" check "$tmp/ok" "$root" >/dev/null || fail "matching file rejected"

# A bare entry for a host, the failure this check exists for, must be caught.
sed '1s/^command="[^"]*",restrict //' "$tmp/good" >"$tmp/bare"
if "$tool" check "$tmp/bare" "$root" 2>/dev/null; then
    fail "unconfined entry accepted"
fi

# A dropped host must be caught.
sed '1d' "$tmp/good" >"$tmp/short"
if "$tool" check "$tmp/short" "$root" 2>/dev/null; then
    fail "missing host accepted"
fi

# A key pointed at another host's repository must be caught.
sed '1s#/borg/[a-z]*"#/borg/other"#' "$tmp/good" >"$tmp/wrongpath"
if "$tool" check "$tmp/wrongpath" "$root" 2>/dev/null; then
    fail "wrong repository path accepted"
fi

echo "ok: rsync-authorized-keys tests passed"
