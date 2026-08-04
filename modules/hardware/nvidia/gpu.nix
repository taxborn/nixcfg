{
  config,
  lib,
  ...
}:
{
  options.myHardware.nvidia.gpu.enable = lib.mkEnableOption "NVIDIA GPU configuration.";

  config = lib.mkIf config.myHardware.nvidia.gpu.enable {
    boot = {
      # i915 must load before the nvidia modules on hybrid Intel+Nvidia
      # systems, otherwise Electron/Chromium apps can stall for up to a
      # minute after boot. See https://wiki.hypr.land/Nvidia/
      initrd.kernelModules = lib.optionals config.myHardware.intel.cpu.enable [ "i915" ];

      # Stage 2 rather than the initrd, and that distinction is the whole point.
      # The udev rules that finegrained power management installs to flip the
      # dGPU to `power/control=auto` only fire on a `bind` action, and they live
      # on the real root. A driver loaded from the initrd has already bound by
      # the time those rules exist, so the event never arrives, the card never
      # reaches RTD3, and it draws power for the entire session — several watts
      # on a laptop, with `runtime_suspended_time` pinned at 0 to prove it.
      # Loading here means the bind happens after switch-root, where udev can
      # see it. The i915 ordering above is preserved either way.
      kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];
    };

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
