{ pkgs, ... }:

{
  imports = [
    ./ghostty
    ./zed.nix
    ./zen.nix
  ];

  home.packages = with pkgs; [
    obsidian
  ];
}
