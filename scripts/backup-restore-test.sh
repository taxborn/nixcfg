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
        echo "PASS $repo — canary"
    else
        echo "FAIL $repo — restored file missing or does not match"
        rc=1
    fi

    # On a host taking database dumps, the file check above is not enough to
    # call the archive good: the live database is excluded in favour of the
    # dump, so a hook that silently failed would leave an archive that restores
    # cleanly and contains no database at all. Assert the dump is really in
    # there. Which hooks to check is derived from the config rather than
    # hardcoded, so a host without a database skips this and a host that grows
    # a second engine is covered without touching this script.
    listing=""
    for hook in postgresql sqlite; do
        grep -q "^${hook}_databases:" "$cfg" || continue

        # Listed once, however many hooks are configured.
        [ -n "$listing" ] ||
            listing=$(borgmatic list --repository "$repo" --archive latest 2>&1 || true)

        # Here-string rather than a pipe into grep. `grep -q` exits at the
        # first match, SIGPIPEing a producer still writing a listing far larger
        # than the pipe buffer; under `pipefail` that makes the pipeline status
        # 141 and inverts the assertion, reporting a dump that is present as
        # missing. Not a race: borgmatic injects the dump patterns at the head
        # of the pattern list, so the match is always in the first few lines
        # and the producer always still has the rest of the archive to write.
        if grep -q "${hook}_databases/" <<<"$listing"; then
            echo "PASS $repo — $hook dump present"
        else
            echo "FAIL $repo — no $hook dump in the archive"
            # The usual cause is an exclude swallowing borgmatic's staging
            # directory (/run under systemd, /tmp when run by hand), which
            # fails silently everywhere else. The dumps sort to the top of the
            # listing, so that is the end worth showing — and it doubles as
            # telling an eaten dump apart from a listing that errored outright.
            head -5 <<<"$listing" | sed 's/^/       | /'
            rc=1
        fi
    done
    echo
done

rm -rf "$scratch"
exit $rc
