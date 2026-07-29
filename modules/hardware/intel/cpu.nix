{ config, lib, ... }:

{
  options.myHardware.intel.cpu.enable = lib.mkEnableOption "Intel CPU configuration.";

  config = lib.mkIf config.myHardware.intel.cpu.enable {
    boot.kernelModules = [ "kvm-intel" ];
    hardware.cpu.intel.updateMicrocode = config.hardware.enableRedistributableFirmware;
  };
}
