{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.services.monitoring.server;

  # An allowlist of filesystems that hold something, rather than a denylist of
  # the ones that do not. tmpfs, ramfs, and the various fuse shims come and go
  # with desktop sessions and portals — a denylist grows a new hole every time
  # one appears, and the hole is a division by a zero-byte "filesystem" rather
  # than anything visibly broken. `fuseblk` is Helium's external NTFS drive
  # under ntfs-3g; `ntfs3` is the same disk if it is ever moved to the kernel
  # driver, and it is listed now so that move does not silently stop alerting.
  realFs = ''fstype=~"btrfs|ext4|xfs|vfat|ntfs3|fuseblk"'';

  # Every btrfs subvolume reports the *pool's* free space, not its own, so a
  # single filesystem on Uranium is six identical series — `/`, `/home`,
  # `/nix`, `/nix/store`, `/home/.snapshots` and the pool itself all share one
  # `device` and one set of numbers. Alerting on the raw series would send six
  # notifications for one full disk. Collapsing on `(instance, device)` is what
  # makes it one, and `min` is the right collapse because these are ratios of
  # the same underlying pool: it picks that pool once.
  fsRatio = ''
    min by (instance, device) (
      node_filesystem_avail_bytes{${realFs}} / node_filesystem_size_bytes{${realFs}}
    )'';

  rules = {
    groups = [
      {
        name = "fleet";
        rules = [
          {
            alert = "InstanceDown";
            # `job="node"` and deliberately not `job=~"node.*"`. The
            # intermittent job holds the laptop and the desktop, where being
            # down is the normal state — see `mySnippets.tailnet.alwaysOn`. A
            # rule that fires every time a lid closes is one that gets muted,
            # and muting it costs this alert, which is the only one that catches
            # a server that simply stopped.
            expr = ''up{job="node"} == 0'';
            for = "10m";
            labels.severity = "critical";
            annotations = {
              summary = "{{ $labels.instance }} is down";
              description = "Prometheus has not scraped {{ $labels.instance }} for 10 minutes.";
            };
          }
          {
            alert = "SystemdUnitFailed";
            # The rule that pays for the whole stack. It turns every failure
            # this config can already have into one notification without a
            # per-service rule: a backup that did not run, a Forgejo runner that
            # died, a Caddy that would not start after a rebuild. Note the label
            # is `name`, not `unit`.
            expr = ''node_systemd_unit_state{state="failed"} == 1'';
            for = "15m";
            labels.severity = "warning";
            annotations = {
              summary = "{{ $labels.name }} failed on {{ $labels.instance }}";
              description = "systemd reports {{ $labels.name }} in the failed state.";
            };
          }
          {
            alert = "MemoryPressure";
            expr = "node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes < 0.10";
            for = "15m";
            labels.severity = "warning";
            annotations = {
              summary = "{{ $labels.instance }} is low on memory";
              description = "Less than 10% of RAM is available, sustained for 15 minutes.";
            };
          }
          {
            alert = "OomKills";
            # Fires on the increment rather than the total, so it reports each
            # new kill once instead of latching on forever after the first.
            expr = "increase(node_vmstat_oom_kill[1h]) > 0";
            for = "5m";
            labels.severity = "warning";
            annotations = {
              summary = "The OOM killer ran on {{ $labels.instance }}";
              description = "{{ $value | printf \"%.0f\" }} process(es) killed in the last hour.";
            };
          }
          {
            alert = "CpuStealHigh";
            # Steal time is the hypervisor running someone else on the core this
            # VM asked for, so it is the one CPU number a guest cannot fix by
            # doing less work. Argon and Carbon are shared OVH instances and
            # this is how a noisy neighbour becomes visible rather than just
            # slow.
            expr = ''avg by (instance) (rate(node_cpu_seconds_total{mode="steal"}[10m])) > 0.10'';
            for = "30m";
            labels.severity = "warning";
            annotations = {
              summary = "{{ $labels.instance }} is losing CPU to steal";
              description = "Over 10% steal time for 30 minutes — the hypervisor is oversubscribed.";
            };
          }
        ];
      }

      {
        name = "storage";
        rules = [
          {
            alert = "DiskSpaceLow";
            expr = "${fsRatio} < 0.10";
            for = "30m";
            labels.severity = "warning";
            annotations = {
              summary = "{{ $labels.device }} on {{ $labels.instance }} is nearly full";
              description = "Under 10% free ({{ $value | humanizePercentage }}).";
            };
          }
          {
            alert = "DiskWillFillIn24h";
            # Two conditions, and the second is what makes this usable. A
            # six-hour trend extrapolated out a day crosses zero constantly on a
            # filesystem that is mostly empty — one large build is enough — and
            # each of those is a false alarm. Requiring the filesystem to also
            # be under 30% free means the extrapolation only speaks when there
            # is little enough left for the trend to matter.
            expr = ''
              min by (instance, device) (
                predict_linear(node_filesystem_avail_bytes{${realFs}}[6h], 24 * 3600)
              ) < 0
              and
              ${fsRatio} < 0.30'';
            for = "1h";
            labels.severity = "warning";
            annotations = {
              summary = "{{ $labels.device }} on {{ $labels.instance }} will fill within a day";
              description = "At the last six hours' rate this filesystem runs out inside 24 hours.";
            };
          }
          {
            alert = "FilesystemReadOnly";
            # btrfs remounts read-only when it hits an error it will not risk
            # writing through. Everything on the host keeps running and quietly
            # fails to persist anything, which is worse than a crash and far
            # easier to miss.
            #
            # `/nix/store` is excluded because NixOS bind-mounts it read-only
            # by default (`boot.readOnlyNixStore`), and the bind inherits the
            # underlying btrfs fstype — so it passes `realFs` and reports
            # `node_filesystem_readonly == 1` on every host, permanently. Left
            # in, this alert never resolves, and an alert that never resolves
            # holds the notification path open until the receiver rate-limits
            # it and every *other* alert stops being delivered too.
            expr = ''node_filesystem_readonly{${realFs}, mountpoint!="/nix/store"} == 1'';
            for = "5m";
            labels.severity = "critical";
            annotations = {
              summary = "{{ $labels.mountpoint }} on {{ $labels.instance }} is read-only";
              description = "The filesystem was remounted read-only, usually after an I/O or consistency error.";
            };
          }
          {
            alert = "MdRaidDegraded";
            # Uranium and Tungsten both boot off an mdadm RAID1. The existing
            # notification path for this is `boot.swraid.mdadmConf =
            # "MAILADDR root"`, which mails a local mailbox nobody opens — so
            # until now a mirror could lose a disk and simply carry on.
            expr = "node_md_degraded > 0";
            for = "5m";
            labels.severity = "critical";
            annotations = {
              summary = "RAID array {{ $labels.device }} on {{ $labels.instance }} is degraded";
              description = "The array is running without full redundancy. Check `cat /proc/mdstat`.";
            };
          }
          {
            alert = "BtrfsDeviceErrors";
            # btrfs keeps per-device counters for read, write, flush, corruption
            # and generation errors. They only ever go up, and they are reset by
            # hand, so alerting on the increment reports each new burst once.
            expr = "increase(node_btrfs_device_errors_total[1h]) > 0";
            for = "15m";
            labels.severity = "critical";
            annotations = {
              summary = "btrfs {{ $labels.type }} errors on {{ $labels.device }} ({{ $labels.instance }})";
              description = "New btrfs {{ $labels.type }} errors in the last hour. Check `btrfs device stats`.";
            };
          }
        ];
      }

      {
        name = "smart";
        rules = [
          {
            alert = "SmartFailing";
            # 1 is passed, 0 is failed. This is the drive's own overall
            # judgement, and it is the single most actionable line in the whole
            # ruleset: a disk that says it is failing generally is.
            expr = "smartctl_device_smart_status == 0";
            for = "5m";
            labels.severity = "critical";
            annotations = {
              summary = "SMART failure on {{ $labels.device }} ({{ $labels.instance }})";
              description = "The drive reports overall SMART health as FAILED. Replace it.";
            };
          }
          {
            alert = "SmartMediaErrors";
            # NVMe's count of unrecovered data integrity errors. Monotonic, so
            # the increment is what matters — a nonzero total from an incident
            # two years ago should not be alerting today.
            expr = "increase(smartctl_device_media_errors[24h]) > 0";
            for = "15m";
            labels.severity = "critical";
            annotations = {
              summary = "New media errors on {{ $labels.device }} ({{ $labels.instance }})";
              description = "{{ $value | printf \"%.0f\" }} new unrecovered errors in 24 hours.";
            };
          }
          {
            alert = "NvmeSpareLow";
            # The drive's own threshold, not a number picked here — NVMe
            # reports both, and crossing it is the controller saying it is
            # running out of blocks to remap into.
            expr = "smartctl_device_available_spare < smartctl_device_available_spare_threshold";
            for = "15m";
            labels.severity = "critical";
            annotations = {
              summary = "{{ $labels.device }} on {{ $labels.instance }} is below its spare threshold";
              description = "Available spare blocks have fallen under the manufacturer's own limit.";
            };
          }
          {
            alert = "NvmeWearHigh";
            # Percentage of rated endurance consumed. Can exceed 100 and the
            # drive keeps working; this is a "start planning" alert, which is
            # why it is the only one here that is not at least a warning about
            # something happening now.
            expr = "smartctl_device_percentage_used > 85";
            for = "1h";
            labels.severity = "warning";
            annotations = {
              summary = "{{ $labels.device }} on {{ $labels.instance }} is {{ $value }}% through its rated life";
              description = "Endurance is largely consumed. Plan a replacement.";
            };
          }
          {
            alert = "DiskTempHigh";
            # The `temperature_type` filter is load-bearing: the exporter also
            # publishes `drive_trip`, the manufacturer's shutdown threshold,
            # which sits around 85-100°C and would satisfy this comparison
            # permanently on every healthy disk.
            expr = ''smartctl_device_temperature{temperature_type="current"} > 60'';
            for = "30m";
            labels.severity = "warning";
            annotations = {
              summary = "{{ $labels.device }} on {{ $labels.instance }} is running hot";
              description = "Sustained above 60°C for half an hour.";
            };
          }
        ];
      }
    ];
  };
in
{
  config = lib.mkIf cfg.enable {
    # JSON, not hand-written YAML, and passed through `builtins.toJSON` — every
    # YAML parser accepts JSON, and this way the quoting of a PromQL expression
    # full of braces and regexes is the language's problem rather than mine.
    #
    # The nixpkgs module runs `promtool check rules` over this at build time, so
    # a malformed expression fails `nixos-rebuild` instead of loading as a rule
    # that never fires. What promtool cannot check is whether a metric name is
    # real: every name used above was verified against live `node_exporter` and
    # `smartctl_exporter` output rather than recalled, because a typo there is
    # silent in exactly the same way.
    services.prometheus.rules = [ (builtins.toJSON rules) ];
  };
}
