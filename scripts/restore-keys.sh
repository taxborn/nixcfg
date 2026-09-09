#!/usr/bin/env bash
set -euo pipefail
identity=$1
cd secrets
for dir in borg/*/; do
    host=$(basename "$dir")
    # printf masks failures in command substitutions used as its arguments.
    # Check the pipelines separately so restore-all cannot report a false pass.
    if ! passphrase_bytes=$(agenix -d "borg/$host/passphrase.age" -i "$identity" | wc -c) ||
            (( passphrase_bytes == 0 )); then
        echo "FAIL $host: could not decrypt a nonempty passphrase" >&2
        exit 1
    fi
    # Consume the entire stream: head can SIGPIPE the decrypting process.
    if ! key_header=$(agenix -d "borg/$host/ssh_key.age" -i "$identity" | sed -n '1p') ||
            [[ "$key_header" != "-----BEGIN OPENSSH PRIVATE KEY-----" ]]; then
        echo "FAIL $host: could not decrypt an OpenSSH private key" >&2
        exit 1
    fi
    printf '%-10s passphrase %4s bytes | key %s\n' \
        "$host" "$passphrase_bytes" "$key_header"
done
