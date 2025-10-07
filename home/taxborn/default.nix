{ pkgs, ... }:

{
  imports = [
    ../features/cli
    ../features/desktop
    ../features/development
  ];

  home.packages = with pkgs; [
    # System information
    neofetch

    dnsutils # `dig` + `nslookup`

    ripgrep
    jq
    fzf

    eza
    btop

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
  ];

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.yazi.enable = true;
  programs.lazygit.enable = true;
  programs.bat.enable = true;

  home.username = "taxborn";
  home.homeDirectory = "/home/taxborn";
  home.stateVersion = "25.05";
}
