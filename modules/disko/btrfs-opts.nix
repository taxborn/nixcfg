# Mount options for every btrfs subvolume on a root disk. Shared so a change to
# compression or discard reaches OVH, Helium and the workstations together.
[
  "compress=zstd:1"
  "discard=async"
  "noatime"
  "rw"
  "space_cache=v2"
  "ssd"
]
