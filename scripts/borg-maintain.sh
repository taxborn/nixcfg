#!/usr/bin/env bash
# Apply retention to the append-only borg repositories, from a workstation.
#
#   borg-maintain.sh IDENTITY [--dry-run] [--yes] [HOST...]
#
# Client keys on Helium and rsync.net are `--append-only`, so the nightly
# borgmatic run never prunes or compacts them. This does, using the
# operator's own access instead of the host's confined key:
#
#   rsync.net  the bare yubikey entry in rsync.net's authorized_keys, reached
#              through the `rsync-backup` ssh alias.
#   Helium     tailnet SSH on port 22, which runs an unrestricted `borg serve`
#              as taxborn. Port 2200 is where the append-only keys live and
#              is deliberately not used here.
#
# The repository passphrase still comes from the host's agenix secret, so each
# host costs one yubikey touch. Retention values come from the host's own
# configuration, so they are written once.
#
# Append-only keeps a log of every transaction, and a client's `delete` or
# `prune` is only applied by the next write from a non-append-only
# connection, which is this script. So the archive count is shown first and
# you confirm before anything is committed. A count that dropped without you
# deleting anything means the host was misbehaving: stop, and revert the
# repository's last transactions (`borg check --repair` on the server
# discards uncommitted segments) before running this again.
#
# No -e: one failing repository must not skip the ones after it.
set -uo pipefail
identity=$1
shift
dry=()
assume_yes=false
hosts=()
for arg in "$@"; do
    case "$arg" in
        --dry-run) dry=(--dry-run) ;;
        --yes) assume_yes=true ;;
        *) hosts+=("$arg") ;;
    esac
done

if ! coverage=$(nix eval --json .#restoreCoverage); then
    exit 1
fi
if ((${#hosts[@]} == 0)); then
    mapfile -t hosts < <(jq -r 'keys[]' <<<"$coverage")
fi

umask 077
scratch=$(mktemp -d "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/borg-maintain.XXXXXXXX") || exit 1
pass=$scratch/pass
trap 'shred -u "$pass" 2>/dev/null || true; rm -rf "$scratch"' EXIT

rc=0
for host in "${hosts[@]}"; do
    if ! plan=$(jq -ce --arg host "$host" '.[$host] // error("unknown backup host")' <<<"$coverage"); then
        rc=1
        continue
    fi
    # Only remote repositories are append-only. Local ones keep pruning from
    # the host's own borgmatic run.
    mapfile -t repos < <(jq -r '. | to_entries[] | select(.value.tier2) | .key' <<<"$plan")
    ((${#repos[@]})) || { echo "SKIP $host: no remote repositories"; continue; }

    if ! retention=$(nix eval --json \
            ".#nixosConfigurations.$host.config.myNixOS.services.backups.client.retention"); then
        rc=1
        continue
    fi
    keep=(
        --keep-daily "$(jq -r .keepDaily <<<"$retention")"
        --keep-weekly "$(jq -r .keepWeekly <<<"$retention")"
        --keep-monthly "$(jq -r .keepMonthly <<<"$retention")"
        --keep-yearly "$(jq -r .keepYearly <<<"$retention")"
    )

    # agenix resolves its argument as a rule name verbatim, so this runs from
    # secrets/. A failed decrypt still leaves an empty file, so check size.
    if ! (cd secrets && agenix -d "borg/$host/passphrase.age" -i "$identity") >"$pass" \
            || [ ! -s "$pass" ]; then
        echo "FAIL $host: could not decrypt the passphrase (wrong PIN?)" >&2
        rc=1
        continue
    fi

    for repo in "${repos[@]}"; do
        echo "== $host -> $repo"
        path=$(jq -r --arg r "$repo" '.[$r].path' <<<"$plan")
        remote_path=$(jq -r --arg r "$repo" '.[$r].remotePath // empty' <<<"$plan")
        rsh="ssh"
        case "$repo" in
            rsync)
                # The alias carries the user and host name, and the operator's
                # own key is what answers.
                url=$(sed -E 's#^ssh://[^/]+#ssh://rsync-backup#' <<<"$path")
                remote=(--remote-path "$remote_path")
                ;;
            helium)
                # Drop the append-only port so Tailscale SSH answers on 22.
                # ~/.ssh/config sets RemoteCommand and RequestTTY for the
                # machine entries, and either corrupts the borg protocol.
                url=$(sed -E 's#^(ssh://[^/:]+):[0-9]+#\1#' <<<"$path")
                rsh="ssh -o RemoteCommand=none -o RequestTTY=no"
                # A non-interactive session does not get the system PATH.
                remote=(--remote-path /run/current-system/sw/bin/borg)
                ;;
            *)
                echo "FAIL $host/$repo: no maintenance route for this backend"
                rc=1
                continue
                ;;
        esac

        borg() {
            nix shell nixpkgs#borgbackup -c env \
                BORG_PASSCOMMAND="cat $pass" BORG_RSH="$rsh" \
                borg "$@"
        }

        if ! names=$(borg list "${remote[@]}" --short "$url"); then
            echo "FAIL $host/$repo: could not list the repository"
            rc=1
            continue
        fi
        echo "archives: $(wc -l <<<"$names"), newest: $(tail -n1 <<<"$names")"
        if ! $assume_yes; then
            read -r -p "Does that count look right? Apply retention? [y/N] " answer
            [[ $answer == y ]] || { echo "SKIP $host/$repo"; continue; }
        fi

        if ! borg prune "${remote[@]}" "${dry[@]}" --list "${keep[@]}" "$url"; then
            echo "FAIL $host/$repo: prune failed"
            rc=1
            continue
        fi
        # compact has no dry run, and nothing was pruned if this was one.
        if ((${#dry[@]} == 0)); then
            if ! borg compact "${remote[@]}" "$url"; then
                echo "FAIL $host/$repo: compact failed"
                rc=1
                continue
            fi
        fi
        echo "PASS $host/$repo"
    done
done
exit $rc
