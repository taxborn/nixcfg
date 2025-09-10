{ pkgs, ... }:

{
  imports = [
    ./network.nix
    ./system-tools.nix
    ./utilities.nix
  ];

  home.packages = with pkgs; [
    # System information
    neofetch

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
}
