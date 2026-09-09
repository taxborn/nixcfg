#!/usr/bin/env bash
set -euo pipefail

mkdir -p mock-bin secrets/borg/argon runtime
export PATH="$PWD/mock-bin:$PATH"
export XDG_RUNTIME_DIR="$PWD/runtime"
export RECIPE_CALLS="$PWD/calls"
export MOCK_PLAN="$PWD/plan.json"
# Deliberately different from deployed destinations, including the remote binary.
jq '.argon.rsync.path = "ssh://backup@example.test/./moved/argon" |
    .argon.rsync.remotePath = "borg-custom"' "$RESTORE_PLAN" >"$MOCK_PLAN"
cat >mock-bin/agenix <<'MOCK'
#!/usr/bin/env bash
printf 'decrypt\n' >>"$RECIPE_CALLS"
case "${KEY_MODE:-ok}:$2" in
    fail-pass:*passphrase.age|fail-key:*ssh_key.age) exit 1 ;;
    empty-pass:*passphrase.age) exit 0 ;;
    bad-key:*ssh_key.age) echo invalid; exit 0 ;;
esac
case "$2" in
    *passphrase.age) echo dummy-passphrase ;;
    *ssh_key.age)
        echo '-----BEGIN OPENSSH PRIVATE KEY-----'
        # Exceeds a pipe buffer, exercising full consumption of the stream.
        head -c 1048576 /dev/zero | tr '\0' x
        ;;
esac
MOCK
cat >mock-bin/nix <<'MOCK'
#!/usr/bin/env bash
if [[ $1 == eval ]]; then
    [[ ${FAIL_EVAL:-0} == 1 ]] && exit 1
    cat "$MOCK_PLAN"
    exit 0
fi
printf '%s\n' "$*" >>"$RECIPE_CALLS"
case " $* " in
    *' borg list '*)
        [[ ${FAIL_LIST:-0} == 1 && $* == *example.test* ]] && exit 1
        echo archive
        ;;
    *' borg extract '*)
        mkdir -p var/lib
        echo canary >var/lib/backup-canary
        ;;
    *) exit 1 ;;
esac
MOCK
cat >mock-bin/ssh <<'MOCK'
#!/usr/bin/env bash
echo canary
MOCK
sed -i "1c#!$(command -v bash)" mock-bin/*
chmod +x mock-bin/*

bash "$RESTORE_KEYS" dummy-identity >keys.log
for mode in fail-pass fail-key empty-pass bad-key; do
    if KEY_MODE=$mode bash "$RESTORE_KEYS" dummy-identity >keys-failure.log 2>&1; then
        echo "Key check incorrectly passed: $mode" >&2
        exit 1
    fi
done

: >calls
bash "$RESTORE_DR" dummy-identity argon rsync helium >restore.log
test "$(grep -c '^decrypt$' calls)" = 2
grep -F 'borg list --remote-path borg-custom' calls
grep -F 'borg extract --remote-path borg-custom ssh://backup@example.test/./moved/argon::archive' calls
helium_url=$(jq -r '.argon.helium.path' "$MOCK_PLAN")
grep -F "borg extract $helium_url::archive" calls
test -z "$(ls -A runtime)"

: >calls
if FAIL_LIST=1 bash "$RESTORE_DR" dummy-identity argon rsync helium >failure.log; then
    echo 'A failed repository must fail the recipe.' >&2
    exit 1
fi
grep -F "borg extract $helium_url::archive" calls
test -z "$(ls -A runtime)"

# Each rejection must happen before decrypting, even after a valid repo argument.
for args in 'missing rsync' 'argon rsync missing'; do
    : >calls
    read -r -a requested <<<"$args"
    if bash "$RESTORE_DR" dummy-identity "${requested[@]}" >invalid.log 2>&1; then
        echo "Invalid request passed: $args" >&2
        exit 1
    fi
    test ! -s calls
done
: >calls
if FAIL_EVAL=1 bash "$RESTORE_DR" dummy-identity argon rsync >eval.log 2>&1; then
    exit 1
fi
test ! -s calls
bash "$RESTORE_DR" dummy-identity helium helium >skip.log
grep -F 'SKIP helium/helium:' skip.log
test ! -s calls
