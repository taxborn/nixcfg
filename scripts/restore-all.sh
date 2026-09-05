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

# Evaluate before touching keys so an invalid coverage plan cannot look like a pass.
if ! coverage=$(nix eval --json .#restoreCoverage); then
    exit 1
fi
if ! hosts=$(jq -r 'keys[]' <<<"$coverage"); then
    exit 1
fi

run "tier 0  key material, all hosts" just restore-keys
for host in $hosts; do
    run "tier 1  $host, all configured repositories" just restore-test "$host"
done
for host in $hosts; do
    mapfile -t repos < <(jq -r --arg host "$host" \
        '.[$host] | to_entries[] | select(.value.tier2) | .key' <<<"$coverage")
    while IFS= read -r reason; do
        results+=("SKIP  tier 2  $host: $reason")
    done < <(jq -r --arg host "$host" \
        '.[$host][] | select(.tier2 | not) | .reason' <<<"$coverage")
    if ((${#repos[@]})); then
        run "tier 2  $host, ${repos[*]}" just restore-dr "$host" "${repos[@]}"
    fi
done

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
