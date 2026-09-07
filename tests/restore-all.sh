#!/usr/bin/env bash
set -euo pipefail

mkdir -p mock-bin
export PATH="$PWD/mock-bin:$PATH"
export RESTORE_CALLS="$PWD/calls"
cat >mock-bin/nix <<'MOCK'
#!/usr/bin/env bash
if [[ ${FAIL_EVAL:-0} == 1 ]]; then exit 1; fi
cat "$RESTORE_PLAN"
MOCK
cat >mock-bin/just <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$RESTORE_CALLS"
if [[ ${FAIL_RESTORE:-0} == 1 && $* == 'restore-test carbon' ]]; then exit 1; fi
exit 0
MOCK
sed -i "1c#!$(command -v bash)" mock-bin/*
chmod +x mock-bin/*

bash "$RESTORE_RUNNER" >success.log
for host in argon carbon helium tungsten uranium; do
    grep -Fx "restore-test $host" calls
    grep -E "^restore-dr $host " calls
done
grep -Fx 'restore-dr helium rsync' calls
grep -Fx 'restore-dr uranium helium rsync' calls
test "$(grep -c '^SKIP  tier 2' success.log)" = 2

: >calls
if FAIL_RESTORE=1 bash "$RESTORE_RUNNER" >failure.log; then
    echo 'A failed canary test must fail the overall run.' >&2
    exit 1
fi
grep -Fx 'restore-dr uranium helium rsync' calls
grep -F 'FAIL  tier 1  carbon' failure.log

: >calls
if FAIL_EVAL=1 bash "$RESTORE_RUNNER" >eval-failure.log; then
    echo 'An invalid coverage plan must fail before decryption.' >&2
    exit 1
fi
test ! -s calls
