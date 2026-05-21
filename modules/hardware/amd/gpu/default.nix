{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHardware.amd.gpu.enable = lib.mkEnableOption "AMD GPU configuration.";

  config = lib.mkIf config.myHardware.amd.gpu.enable {
    environment.variables = {
      VDPAU_DRIVER = "radeonsi";
      GSK_RENDERER = "ngl";
    };

    # Unlock amdgpu OverDrive (undervolt / fan curves / power limits via
    # LACT or CoreCtrl). No runtime effect until a userspace tool writes
    # to the exposed sysfs nodes, but required to make those nodes appear.
    boot.kernelParams = [ "amdgpu.ppfeaturemask=0xffffffff" ];

    hardware = {
      amdgpu = {
        initrd.enable = true;
        opencl.enable = true;
      };

      graphics = {
        enable = true;
        extraPackages = with pkgs; [
          mesa
          vulkan-loader
          vulkan-tools
        ];
      };
    };
  };
}
