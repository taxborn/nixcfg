#!/usr/bin/env bash
# Canary round-trip through every borg repository configured on this host.
#
# Writes a timestamp into the backup set, backs up, then extracts that one file
# from each repository and compares it byte-for-byte against the original. Run
# as root on the host itself; `just restore-test <host>` does that over ssh.
set -euo pipefail

canary=/var/lib/backup-canary
scratch=/var/tmp/borg-restore-test

date -Is >"$canary"
echo "canary: $(cat "$canary")"
echo

borgmatic create --verbosity 1

rc=0
# One config per repository, named after its label — see the module's
# `configurations` mapping. Deriving the list from disk means a third target
# gets tested the moment it is deployed.
for cfg in /etc/borgmatic.d/*.yaml; do
    repo=$(basename "$cfg" .yaml)
    dest="$scratch/$repo"

    echo "== $repo"
    # borgmatic chdirs into --destination rather than creating it.
    rm -rf "$dest"
    mkdir -p "$dest"

    # Confirms `repokey`: the borg key lives in the repository, so the
    # passphrase alone is enough to recover — there is no keyfile to lose.
    borgmatic repo-info --repository "$repo" | grep -i '^Encrypted:' || true

    borgmatic extract --repository "$repo" --archive latest \
        --path "${canary#/}" --destination "$dest"

    # The comparison is the assertion, not borg's exit code: a --path that
    # matches nothing still exits 0 and leaves an empty destination.
    if diff -q "$dest/${canary#/}" "$canary" >/dev/null 2>&1; then
        echo "PASS $repo"
    else
        echo "FAIL $repo — restored file missing or does not match"
        rc=1
    fi
    echo
done

rm -rf "$scratch"
exit $rc
