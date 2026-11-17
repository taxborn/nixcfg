let

  realFs = ''fstype=~"btrfs|ext4|xfs|vfat|ntfs3|fuseblk"'';

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
            expr = ''node_systemd_unit_state{state="failed"} == 1'';
            for = "15m";
            labels.severity = "warning";
            annotations = {
              summary = "{{ $labels.name }} failed on {{ $labels.instance }}";
              description = "systemd reports {{ $labels.name }} in the failed state.";
            };
          }
          {
            alert = "BackupStale";
            # SystemdUnitFailed cannot see a timer that stopped firing.
            expr = ''time() - node_systemd_timer_last_trigger_seconds{job="node", name="borgmatic.timer"} > 36 * 3600'';
            for = "30m";
            labels.severity = "warning";
            annotations = {
              summary = "no backup on {{ $labels.instance }} for 36 hours";
              description = "borgmatic.timer last fired more than 36 hours ago on {{ $labels.instance }}.";
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
            expr = ''avg by (instance) (rate(node_cpu_seconds_total{mode="steal"}[10m])) > 0.10'';
            for = "30m";
            labels.severity = "warning";
            annotations = {
              summary = "{{ $labels.instance }} is losing CPU to steal";
              description = "Over 10% steal time for 30 minutes, the hypervisor is oversubscribed.";
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
            # /nix/store is a read-only bind mount. Left in, this never resolves and blocks other alerts.
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
            # Without the filter the drive trip point matches permanently.
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
  services.prometheus.rules = [ (builtins.toJSON rules) ];
}
