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

    # zram gives us a compressed in-RAM swap tier sitting in front of the
    # disk swapfile. On a 13700K the zstd compression is effectively free
    # and usually reclaims ~3x its allocation. Priority defaults higher
    # than disk swap, so cold pages hit zram first.
    zramSwap = {
      enable = true;
      algorithm = "zstd";
      memoryPercent = 25;
    };
  };
}
