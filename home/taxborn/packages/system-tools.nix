{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # System monitoring
    btop # replacement of htop/nmon
    iotop # io monitoring
    iftop # network monitoring

    # System call monitoring
    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    # System information and tools
    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb
  ];
}
