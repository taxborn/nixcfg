{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ripgrep
    jq
    fzf

    eza
  ];
}
