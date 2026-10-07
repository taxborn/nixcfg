{
  config,
  lib,
  ...
}:
let
  cfg = config.myNixOS.profiles.swap;
in
{
  options.myNixOS.profiles.swap.enable = lib.mkEnableOption "swap and oomd configurations";

  config = lib.mkIf cfg.enable {
    systemd.oomd = {
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
    };

    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
    };

    # Both defaults assume swap is a disk, and neither holds once zram is the
    # only swap device. A swap-in here is a decompression rather than a seek,
    # cheap enough that the kernel should reach for it well before it starts
    # dropping page cache, which is not the trade a swappiness of 60 makes.
    # page-cluster is swap readahead. The default faults in eight pages to
    # amortise a seek that does not exist here, so seven of them are
    # decompressions done on speculation. 0 turns it off.
    boot.kernel.sysctl = {
      "vm.swappiness" = 180;
      "vm.page-cluster" = 0;
    };
  };
}
