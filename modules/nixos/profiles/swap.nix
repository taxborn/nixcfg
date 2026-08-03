{
  config,
  lib,
  ...
}:
{
  options.myNixOS.profiles.swap.enable = lib.mkEnableOption "swap and oomd configurations";

  config = lib.mkIf config.myNixOS.profiles.swap.enable {
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

    # Both defaults assume swap is a disk, and neither is true once zram is the
    # only swap device.
    #
    # A swap-in from zram is a decompression, not a seek — cheap enough that the
    # kernel should reach for it well before it starts dropping page cache,
    # which is not the trade the default swappiness of 60 makes.
    #
    # page-cluster is swap readahead. The default 3 faults in eight pages at a
    # time to amortise a seek that does not exist here, so seven of them are
    # decompressions paid for on speculation. 0 turns it off.
    boot.kernel.sysctl = {
      "vm.swappiness" = 180;
      "vm.page-cluster" = 0;
    };
  };
}
