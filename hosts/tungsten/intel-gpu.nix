{
  config,
  lib,
  pkgs,
  ...
}:
{
  hardware.graphics = {
    enable = true;

    extraPackages = with pkgs; [
      intel-media-driver
      vpl-gpu-rt
      intel-compute-runtime
    ];

    extraPackages32 = lib.mkIf config.hardware.graphics.enable32Bit [
      pkgs.driversi686Linux.intel-media-driver
    ];
  };
}
