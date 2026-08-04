{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHardware.intel.gpu.enable = lib.mkEnableOption "Intel GPU configuration.";

  config = lib.mkIf config.myHardware.intel.gpu.enable {
    hardware.graphics = {
      enable = true;

      extraPackages = with pkgs; [
        intel-media-driver # VAAPI, via iHD
        vpl-gpu-rt # oneVPL — the encode runtime on Gen12 and later
        intel-compute-runtime # OpenCL
      ];

      # Only consulted when something else asks for 32-bit support, which on the
      # workstations is the nvidia module. Worth setting anyway: without it a
      # host with `enable32Bit` has no 32-bit VAAPI at all, and wine and Steam
      # quietly fall back to software decode.
      extraPackages32 = lib.mkIf config.hardware.graphics.enable32Bit [
        pkgs.driversi686Linux.intel-media-driver
      ];
    };
  };
}
