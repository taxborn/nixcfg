{
  config,
  lib,
  ...
}:
{
  options.myHardware.nvidia.gpu.enable = lib.mkEnableOption "NVIDIA GPU configuration.";

  config = lib.mkIf config.myHardware.nvidia.gpu.enable {
    # i915 must load before the nvidia modules on hybrid Intel+Nvidia
    # systems, otherwise Electron/Chromium apps can stall for up to a
    # minute after boot. See https://wiki.hypr.land/Nvidia/
    boot.initrd.kernelModules =
      lib.optionals config.myHardware.intel.cpu.enable [ "i915" ]
      ++ [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];

    hardware = {
      graphics = {
        enable = true;
        enable32Bit = true;
      };

      nvidia = {
        open = true;
        powerManagement.enable = true;
      };
    };

    services.xserver.videoDrivers = [ "nvidia" ];
  };
}
