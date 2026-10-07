{ config, lib, ... }:
let
  cfg = config.myHardware.intel.cpu;
in
{
  options.myHardware.intel.cpu.enable = lib.mkEnableOption "Intel CPU configuration";

  config = lib.mkIf cfg.enable {
    boot.kernelModules = [ "kvm-intel" ];
    hardware.cpu.intel.updateMicrocode = config.hardware.enableRedistributableFirmware;
  };
}
