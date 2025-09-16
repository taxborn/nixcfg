{
  imports = [
    ./default.nix

    ./applications

    ../features/cli/fish.nix
    ../features/cli/tmux.nix
    ../features/desktop/hyprland
    ../features/desktop/fonts.nix
  ];
}
