{ pkgs, config, ... }:

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
  ];

  home.username = "taxborn";
  home.homeDirectory = "/home/taxborn";
  home.stateVersion = "25.05";

  sops = {
    age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt"; # must have no password!

    defaultSopsFile = ../../secrets.yaml;
    defaultSymlinkPath = "/run/user/1000/secrets";
    defaultSecretsMountPoint = "/run/user/1000/secrets.d";
  };

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

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.yazi.enable = true;
  programs.lazygit.enable = true;
  programs.bat.enable = true;

  home.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    NIXOS_OZONE_WL = 1; # fixed electron apps blurriness
  };
}
