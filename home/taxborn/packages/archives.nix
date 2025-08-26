{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # Archive utilities
    zip
    unzip
    xz
    p7zip
  ];
}
