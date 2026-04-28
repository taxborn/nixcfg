{
  config,
  lib,
  ...
}:
{
  options.myNixOS.profiles.swap.enable = lib.mkEnableOption "swap and oomd configurations";

  config = lib.mkIf config.myNixOS.profiles.swap.enable {
    systemd.oomd = {
      enable = true;
      enableRootSlice = true;
      enableSystemSlice = true;
      enableUserSlices = true;
    };

    # zram is the only swap tier; hosts no longer carry a disk swapfile.
    # zstd typically reclaims ~3x its allocation, so 50% of RAM as zram
    # yields roughly 1.5x effective swap headroom while only consuming
    # physical RAM proportional to actually-stored pages.
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 50;
    };
  };
}
