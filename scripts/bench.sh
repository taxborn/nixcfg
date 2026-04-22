#! /usr/bin/env nix-shell
#! nix-shell -i bash -p fio sysbench hyperfine p7zip coreutils util-linux procps

# shellcheck shell=bash
# Perf bench harness. Captures a snapshot of system + synthetic + end-to-end
# metrics to stdout. Redirect to a file tagged "before" / "after" a change and
# diff the two to see impact.
#
# Usage:
#   scripts/bench.sh > /tmp/bench-before.txt
#   # ...apply changes, rebuild, reboot if needed...
#   scripts/bench.sh > /tmp/bench-after.txt
#   diff -u /tmp/bench-before.txt /tmp/bench-after.txt
#
# Runtime: ~3-5 minutes. Keep the workload stable while it runs (no builds,
# no gaming, no compilation). Accepts one optional positional arg: a label
# that gets printed at the top.

set -euo pipefail

LABEL="${1:-unlabeled}"
WORKDIR="${BENCH_WORKDIR:-/tmp/bench-$$}"
mkdir -p "$WORKDIR"
trap 'rm -rf "$WORKDIR"' EXIT

hdr() { printf '\n===== %s =====\n' "$1"; }

hdr "meta"
printf 'label:        %s\n' "$LABEL"
printf 'timestamp:    %s\n' "$(date -Iseconds)"
printf 'host:         %s\n' "$(hostname)"
printf 'kernel:       %s\n' "$(uname -r)"
printf 'nixos:        %s\n' "$(nixos-version)"
printf 'uptime:       %s\n' "$(awk '{printf "%d sec", $1}' /proc/uptime)"

hdr "boot"
systemd-analyze | head -1 || true
systemd-analyze critical-chain --no-pager 2>/dev/null | head -15 || true

hdr "load / pressure"
printf 'loadavg:      %s\n' "$(cat /proc/loadavg)"
printf 'cpu psi:      %s\n' "$(awk '/some/{print}' /proc/pressure/cpu)"
printf 'mem psi:      %s\n' "$(awk '/some/{print}' /proc/pressure/memory)"
printf 'io psi:       %s\n' "$(awk '/some/{print}' /proc/pressure/io)"

hdr "memory"
free -h

hdr "journal"
printf 'journal size: %s\n' "$(journalctl --disk-usage 2>&1 | tail -1)"

hdr "service memory (top 10 by RSS)"
systemctl --no-pager --no-legend list-units --type=service --state=running |
  awk '{print $1}' |
  while read -r u; do
    mem=$(systemctl show -p MemoryCurrent --value "$u" 2>/dev/null)
    [[ -n "$mem" && "$mem" != "[not set]" && "$mem" -gt 0 ]] 2>/dev/null && \
      printf '%12d  %s\n' "$mem" "$u"
  done | sort -rn | head -10

hdr "cpufreq"
printf 'governor:     %s\n' "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor)"
printf 'driver:       %s\n' "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver)"
printf 'freq sample:  '
for c in /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq; do
  awk 'END{printf "%d ",$1/1000}' "$c"
done
echo "MHz"

hdr "sysbench cpu (10s, all threads)"
sysbench cpu --threads="$(nproc)" --time=10 run 2>&1 | \
  grep -E "events per second|total time|min:|avg:|max:|95th"

hdr "sysbench memory (seq write, 10s)"
sysbench memory --memory-total-size=50G --memory-oper=write \
  --memory-access-mode=seq --threads=4 --time=10 run 2>&1 | \
  grep -E "Total operations|transferred|latency"

hdr "7z bench (compression, 30s)"
7z b -mmt"$(nproc)" 2>/dev/null | grep -E "CPU|Tot:|MIPS" | tail -5

hdr "fio random 4k read+write (crypthome, 10s)"
fio --name=rand4k --directory="$HOME" --rw=randrw --rwmixread=70 \
  --bs=4k --ioengine=io_uring --size=512M --numjobs=4 \
  --iodepth=32 --runtime=10 --time_based --direct=0 --group_reporting \
  --output-format=terse 2>/dev/null | \
  awk -F';' '{printf "read  iops=%s  bw=%s KiB/s  lat_us=%s\n", $8, $7, $40;
              printf "write iops=%s  bw=%s KiB/s  lat_us=%s\n", $49, $48, $81}'
rm -f "$HOME"/rand4k.*.0

hdr "fio seq 1M read (crypthome, 5s)"
fio --name=seq1m --directory="$HOME" --rw=read --bs=1M \
  --ioengine=io_uring --size=1G --numjobs=1 --iodepth=8 \
  --runtime=5 --time_based --direct=0 --output-format=terse 2>/dev/null | \
  awk -F';' '{printf "read  bw=%s KiB/s  iops=%s\n", $7, $8}'
rm -f "$HOME"/seq1m.*.0

hdr "hyperfine: nix eval flake attr"
hyperfine --warmup 1 --runs 3 --export-json "$WORKDIR/hf.json" \
  "nix eval --raw .#nixosConfigurations.uranium.config.networking.hostName" 2>&1 | \
  grep -E "Time|min|max|mean"

hdr "end"
printf 'done:         %s\n' "$(date -Iseconds)"
