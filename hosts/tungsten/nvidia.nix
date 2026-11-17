{
  boot = {
    initrd.kernelModules = [ "i915" ];

    # Stage 2, so the power-management udev rules see the bind. See docs/hosts.md.
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
}
