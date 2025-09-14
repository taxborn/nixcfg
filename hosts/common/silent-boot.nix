{ lib, ... }:

{
  boot = {
    # Enable "Silent boot"
    consoleLogLevel = lib.mkDefault 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
    ];
    loader = {
      timeout = 0;
      # efi.canTouchEfiVariables = true;
    };
  };
}
