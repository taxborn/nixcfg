{ pkgs, ... }:

{
  imports = [
    ./zed.nix
    ./zen.nix
  ];

  home.packages = with pkgs; [
    obsidian
  ];
}
