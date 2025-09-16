{ pkgs, ... }:

{
  imports = [
    ./neovim
    ./zed.nix
    ./zen.nix
  ];
}
