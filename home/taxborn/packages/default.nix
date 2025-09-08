{ pkgs, ... }:

{
  imports = [
    ./archives.nix
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
    gnupg
  ];
}
