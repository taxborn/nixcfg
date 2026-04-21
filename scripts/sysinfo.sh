#! /usr/bin/env nix-shell
#! nix-shell -i bash -p util-linux pciutils usbutils dmidecode iproute2 lshw coreutils gnugrep gawk

# shellcheck shell=bash
set -euo pipefail

BOLD='\033[1m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
GREEN='\033[0;32m'
RESET='\033[0m'

section() {
  echo -e "\n${BOLD}${CYAN}=== $1 ===${RESET}"
}

kv() {
  printf "  ${YELLOW}%-24s${RESET} %s\n" "$1:" "$2"
}

# ---- identity ----------------------------------------------------------------
section "Host"
kv "Hostname"    "$(hostname -f 2>/dev/null || hostname)"
kv "OS"          "$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')"
kv "Kernel"      "$(uname -r)"
kv "Architecture" "$(uname -m)"
kv "Uptime"      "$(uptime -p 2>/dev/null | sed 's/up //' || uptime)"

# ---- cpu ---------------------------------------------------------------------
section "CPU"
CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | xargs)
CPU_PHYS=$(grep 'physical id' /proc/cpuinfo | sort -u | wc -l)
CPU_CORES=$(grep -c '^processor' /proc/cpuinfo)
CPU_THREADS=$(nproc)
CACHE_L3=$(grep -m1 'cache size' /proc/cpuinfo | cut -d: -f2 | xargs)

kv "Model"        "$CPU_MODEL"
kv "Sockets"      "$CPU_PHYS"
kv "Cores"        "$CPU_CORES"
kv "Threads"      "$CPU_THREADS"
kv "L3 cache"     "${CACHE_L3:-unknown}"

CPU_MHZ=$(grep -m1 'cpu MHz' /proc/cpuinfo | cut -d: -f2 | xargs | awk '{printf "%.0f MHz", $1}')
kv "Freq (live)"  "$CPU_MHZ"

# ---- memory ------------------------------------------------------------------
section "Memory"
MEM_TOTAL=$(awk '/MemTotal/ {printf "%.1f GiB", $2/1048576}' /proc/meminfo)
MEM_FREE=$(awk '/MemAvailable/ {printf "%.1f GiB", $2/1048576}' /proc/meminfo)
MEM_USED=$(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{printf "%.1f GiB", (t-a)/1048576}' /proc/meminfo)
SWAP_TOTAL=$(awk '/SwapTotal/ {printf "%.1f GiB", $2/1048576}' /proc/meminfo)
SWAP_FREE=$(awk '/SwapFree/ {printf "%.1f GiB", $2/1048576}' /proc/meminfo)

kv "Total"        "$MEM_TOTAL"
kv "Used"         "$MEM_USED"
kv "Available"    "$MEM_FREE"
kv "Swap total"   "$SWAP_TOTAL"
kv "Swap free"    "$SWAP_FREE"

# DIMM details via dmidecode (needs root; skip gracefully if unavailable)
if [ "$(id -u)" -eq 0 ]; then
  echo ""
  dmidecode -t memory 2>/dev/null \
    | awk '
      /Memory Device$/ { in_dev=1; size=""; speed=""; type=""; loc="" }
      in_dev && /^\tSize:/ && $2!="No" { size=$2" "$3 }
      in_dev && /^\tSpeed:/ && $2!="Unknown" { speed=$2" "$3 }
      in_dev && /^\tType:/ && !/Type Detail/ && $2!="Unknown" { type=$2 }
      in_dev && /^\tLocator:/ && !/Bank/ { loc=$2 }
      in_dev && /^$/ && size!="" {
        printf "  %-24s %s %s @ %s\n", loc":", size, type, speed
        in_dev=0
      }
    '
else
  echo -e "  ${GREEN}(run as root to see DIMM slot details)${RESET}"
fi

# ---- storage -----------------------------------------------------------------
section "Storage"
lsblk -o NAME,SIZE,TYPE,ROTA,TRAN,MODEL,MOUNTPOINTS \
      --exclude 7 \
      --tree \
  2>/dev/null || lsblk -o NAME,SIZE,TYPE,ROTA,MODEL

echo ""
echo -e "  ${BOLD}Filesystem usage:${RESET}"
df -h --output=source,size,used,avail,pcent,target \
   -x tmpfs -x devtmpfs -x efivarfs 2>/dev/null \
  | awk 'NR==1{printf "  %-36s %6s %6s %6s %5s  %s\n",$1,$2,$3,$4,$5,$6; next}
         {printf "  %-36s %6s %6s %6s %5s  %s\n",$1,$2,$3,$4,$5,$6}'

# ---- network -----------------------------------------------------------------
section "Network"
ip -o addr show scope global 2>/dev/null \
  | awk '{printf "  %-16s %-12s %s\n", $2, $3, $4}'

echo ""
echo -e "  ${BOLD}Default routes:${RESET}"
ip route show default 2>/dev/null | awk '{printf "  %s\n", $0}'

# ---- pci devices -------------------------------------------------------------
section "PCI Devices"
lspci -mm 2>/dev/null \
  | awk -F'"' '{printf "  %-32s %s -- %s\n", $2, $4, $6}' \
  | sort

# ---- usb devices -------------------------------------------------------------
section "USB Devices (non-hubs)"
lsusb 2>/dev/null \
  | grep -v 'Linux Foundation' \
  | grep -v 'root hub' \
  | sed 's/^/  /' \
  || true

# ---- nix specifics -----------------------------------------------------------
section "NixOS"
if command -v nixos-version &>/dev/null; then
  kv "NixOS version" "$(nixos-version 2>/dev/null)"
fi
if command -v nix &>/dev/null; then
  kv "Nix version"   "$(nix --version 2>/dev/null)"
fi
NIX_STORE_SIZE=$(du -sh /nix/store 2>/dev/null | cut -f1)
kv "/nix/store size" "${NIX_STORE_SIZE:-unknown}"
kv "Generations" "$(ls /nix/var/nix/profiles/ 2>/dev/null | grep -c 'system-' || echo 0)"

# ---- summary for homelab planning --------------------------------------------
section "Summary"
echo -e "  ${GREEN}Host:${RESET}    $(hostname)"
echo -e "  ${GREEN}CPU:${RESET}     $CPU_CORES cores / $CPU_THREADS threads -- $CPU_MODEL"
echo -e "  ${GREEN}RAM:${RESET}     $MEM_TOTAL total, $MEM_USED used"
echo -e "  ${GREEN}Disks:${RESET}"
lsblk -d -o NAME,SIZE,TRAN,MODEL --exclude 7 2>/dev/null \
  | tail -n +2 \
  | sed 's/^/             /'
