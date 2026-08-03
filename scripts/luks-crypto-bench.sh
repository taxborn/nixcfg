#!/usr/bin/env bash
# Measure what dm-crypt is costing on each LUKS mapping, so the effect of
# putting aesni_intel in the initrd can be seen before and after a reboot.
#
# The trick is that every mapping is measured twice: once through
# /dev/mapper/<name> (plaintext, decrypted on the way out) and once against the
# device underneath it (ciphertext, no dm-crypt in the path). Their ratio is the
# fraction of the storage's throughput that survives decryption, which is what
# the initrd change actually moves. Absolute MB/s wanders with drive state and
# thermals; the ratio does not, so it is the number worth comparing across runs.
#
# cryptroot is the mapping under test — it is unlocked in stage 1, where the
# available cipher implementations are whatever the initrd shipped. games is
# opened in stage 2 from /etc/crypttab and has always had the accelerated path,
# so it stands in as a reference for what a healthy ratio looks like on this
# machine.
#
# Reads only, O_DIRECT, nothing is written to any block device.
#
# Usage: sudo ./scripts/luks-crypto-bench.sh before
#        (reboot)
#        sudo ./scripts/luks-crypto-bench.sh after
set -euo pipefail

tag=${1:-run}
log=/var/tmp/luks-crypto-bench.log
mappings=(cryptroot games)
gib=${BENCH_GIB:-8}
runs=${BENCH_RUNS:-3}

if [[ $EUID -ne 0 ]]; then
  echo "needs root: raw block reads and O_DIRECT are not available to a user" >&2
  exit 1
fi

# This gets run from whichever shell happens to be open, including a nix-shell
# with a replaced PATH. Fail loudly on a missing tool rather than letting a
# substitution come back empty and report something plausible but wrong.
for tool in dd awk date; do
  command -v "$tool" >/dev/null || {
    echo "missing required tool: $tool" >&2
    exit 1
  }
done

# Best of N, because a single pass catches mdraid read balancing warming up and
# the drives' own caches settling. Slowest run is the noisy one, not the truth.
throughput_mb_s() {
  local dev=$1 best=0 i start end mb
  dd if="$dev" of=/dev/null bs=8M count=32 iflag=direct status=none 2>/dev/null || true
  for ((i = 0; i < runs; i++)); do
    start=$(date +%s%N)
    dd if="$dev" of=/dev/null bs=8M count=$((gib * 128)) iflag=direct status=none
    end=$(date +%s%N)
    mb=$(awk -v b="$((gib * 1024))" -v ns="$((end - start))" 'BEGIN { printf "%.0f", b / (ns / 1e9) }')
    ((mb > best)) && best=$mb
  done
  echo "$best"
}

{
  echo "=== $tag  $(date -Is)"
  echo "kernel:    $(uname -r)"
  echo "system:    $(readlink -f /run/current-system)"
  # Read the module's own sysfs directory instead of shelling out to lsmod,
  # which is not on a bare nix-shell PATH. That is not hypothetical: a run of
  # this script reported "NOT LOADED" while the /proc/crypto block directly
  # below it listed algorithms only aesni_intel registers.
  if [[ -d /sys/module/aesni_intel ]]; then
    echo "aesni:     loaded (refcnt $(cat /sys/module/aesni_intel/refcnt 2>/dev/null || echo n/a))"
  else
    echo "aesni:     not loaded"
  fi

  # An xts(aes) entry whose driver name is a template instance rather than one
  # of aesni_intel's own is the signature of a mapping that bound the generic
  # implementation and is stuck with it.
  echo "xts(aes) implementations in use:"
  awk '/^name +: xts\(aes\)/ { n = 1 }
       n && /^driver/        { d = $3 }
       n && /^refcnt/        { printf "  %-24s refcnt %s\n", d, $3; n = 0 }' /proc/crypto

  echo
  printf "  %-12s %12s %12s %10s\n" mapping plaintext ciphertext efficiency
  for m in "${mappings[@]}"; do
    [[ -e /dev/mapper/$m ]] || continue
    # /dev/mapper/<name> is a symlink to the dm-N kernel name, and that device's
    # slaves/ directory holds the device the mapping sits on — the one to read
    # for the ciphertext side. Resolved through sysfs for the same reason as
    # above: no dependency on lsblk being present.
    kname=$(basename "$(readlink -f "/dev/mapper/$m")")
    backing=$(ls "/sys/block/$kname/slaves/" | head -1)

    plain=$(throughput_mb_s "/dev/mapper/$m")
    cipher=$(throughput_mb_s "/dev/$backing")
    ratio=$(awk -v p="$plain" -v c="$cipher" 'BEGIN { printf "%.2f", (c > 0 ? p / c : 0) }')

    printf "  %-12s %9s MB/s %9s MB/s %9sx  (over %s)\n" \
      "$m" "$plain" "$cipher" "$ratio" "$backing"
  done
  echo
} | tee -a "$log"

echo "appended to $log"
