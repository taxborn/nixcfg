{
  config,
  lib,
  ...
}:
{
  options.myNixOS.profiles.performance.enable = lib.mkEnableOption "performance tunings";

  config = lib.mkIf config.myNixOS.profiles.performance.enable {
    boot.kernel.sysctl = {
      # Improved file monitoring
      "fs.file-max" = lib.mkDefault 2097152; # Set size of file handles and inode cache
      "fs.inotify.max_user_instances" = lib.mkOverride 100 8192; # Re-use the default from Bazzite even though the default NixOS value is higher.
      "fs.inotify.max_user_watches" = lib.mkOverride 100 524288;

      "kernel.nmi_watchdog" = lib.mkOverride 100 0; # Disable watchdogs for maximum performance at the cost of resiliency
      "kernel.soft_watchdog" = lib.mkDefault 0;
      "kernel.split_lock_mitigate" = lib.mkDefault 0;
      # "kernel.unprivileged_userns_clone" = lib.mkDefault 1;
      "kernel.watchdog" = lib.mkDefault 0;

      # Network optimizations
      "net.core.default_qdisc" = lib.mkDefault "fq";
      "net.core.netdev_max_backlog" = lib.mkDefault 16384; # Increase netdev receive queue
      "net.ipv4.tcp_congestion_control" = lib.mkDefault "bbr";
      "net.ipv4.tcp_ecn" = lib.mkDefault 1;
      "net.ipv4.tcp_fastopen" = lib.mkDefault 3;
      "net.ipv4.tcp_fin_timeout" = lib.mkDefault 5;
      "net.ipv4.tcp_mtu_probing" = lib.mkForce 1;
      "net.ipv4.tcp_rfc1337" = lib.mkDefault 1; # Protect against tcp time-wait assassination hazards, drop RST packets for sockets in the time-wait state. Not widely supported outside of Linux, but conforms to RFC.
      "net.ipv4.tcp_slow_start_after_idle" = 0; # Disable TCP slow start after idle
      # "net.ipv4.tcp_timestamps" = lib.mkDefault 0; # https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux_for_real_time/7/html/tuning_guide/reduce_tcp_performance_spikes

      # Memory management. Dirty thresholds sized for fast NVMe (let the
      # kernel batch up to 1 GiB of dirty pages before forcing writeback
      # and kick background writeback at 256 MiB). Small-disk/rotational
      # hosts should override these back down.
      "vm.dirty_background_bytes" = lib.mkDefault 268435456;
      "vm.dirty_bytes" = lib.mkDefault 1073741824;
      "vm.dirty_writeback_centisecs" = lib.mkDefault 1500;
      "vm.max_map_count" = lib.mkOverride 100 2147483642;
      "vm.page-cluster" = lib.mkDefault 0;
      # With zram in front of disk swap, 60 is a good balance: eager
      # enough to make use of compressed RAM, not so eager that cold
      # pages get pushed to an encrypted on-disk swapfile. Was 100
      # (assumed zram-only); lowered after seeing swappiness=100 +
      # btrfs swapfile on LUKS incur real cost under pressure.
      "vm.swappiness" = lib.mkDefault 60;
      "vm.vfs_cache_pressure" = lib.mkDefault 75;
      "vm.watermark_boost_factor" = lib.mkDefault 0;
      "vm.watermark_scale_factor" = lib.mkDefault 125;
    };

    hardware.block = {
      # Default schedulers for rotational and non-rotational devices
      defaultScheduler = "kyber";
      defaultSchedulerRotational = "bfq";

      scheduler = {
        "mmcblk[0-9]*" = "bfq";
        "nvme[0-9]*" = "kyber";
      };
    };

    services = {
      bpftune.enable = true;

      scx = {
        enable = true;
        scheduler = "scx_bpfland";
      };
    };

    # Defer bpftune post-boot. Its auto-generated cgroupv2 mount
     # (/run/bpftune/cgroupv2) otherwise lands on the critical chain via
     # local-fs.target. Auto-tuning doesn't need to start at t=0; 10s
     # after boot is fine and keeps the graphical path clean.
    systemd.services.bpftune = {
      wantedBy = lib.mkForce [ ];
      before = lib.mkForce [ ];
    };

    systemd.timers.bpftune = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "10s";
        Unit = "bpftune.service";
      };
    };
  };
}
