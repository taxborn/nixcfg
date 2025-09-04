{ pkgs, ... }:

{
  home.packages = with pkgs; [
    ripgrep # recursively searches directories for a regex pattern
    jq # A lightweight and flexible command-line JSON processor
    yq-go # yaml processor https://github.com/mikefarah/yq
    fzf # A command-line fuzzy finder

    # File management
    eza # A modern replacement for 'ls'
  ];
}
