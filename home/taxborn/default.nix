{ pkgs, ... }:

{
  imports = [
    ./gpg
  ];

  home.packages = with pkgs; [
    # System information
    neofetch

    dnsutils # `dig` + `nslookup`
    nmap

    ripgrep
    jq
    fzf

    eza
    btop
    iotop # io monitoring
    iftop # network monitoring

    strace # system call monitoring
    ltrace # library call monitoring
    lsof # list open files

    sysstat
    lm_sensors # for `sensors` command
    ethtool
    pciutils # lspci
    usbutils # lsusb

    # Miscellaneous
    file
    which
    tree
    gnused
    gnutar
    gawk
    zstd

    # Archive utilities
    zip
    unzip
    xz
    p7zip

    # etc
    prismlauncher
  ];

  home.username = "taxborn";
  home.homeDirectory = "/home/taxborn";
  home.stateVersion = "25.05";

  programs.git = {
    enable = true;
    userName = "Braxton Fair";
    userEmail = "hello@taxborn.com";

    lfs.enable = true;

    signing.key = "F22AFD6CFD66B874";
    signing.signByDefault = true;

    extraConfig = {
      push.autoSetupRemote = true;
      init.defaultBranch = "main";
    };
  };
}
