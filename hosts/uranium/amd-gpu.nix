{
  environment.variables.VDPAU_DRIVER = "radeonsi";

  boot.kernelParams = [ "amdgpu.ppfeaturemask=0xffffffff" ];

  hardware = {
    amdgpu = {
      initrd.enable = true;
      opencl.enable = true;
    };

    graphics.enable = true;
  };
}
