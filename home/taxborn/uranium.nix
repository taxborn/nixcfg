{
  imports = [
    ./default.nix

    ../features/cli/fish.nix
    ../features/cli/tmux.nix

    ../features/desktop/ghostty
    ../features/desktop/hyprland
    ../features/desktop/fonts.nix
    ../features/desktop/etc.nix
    ../features/desktop/minecraft.nix
    ../features/desktop/obs.nix
    ../features/desktop/zen.nix

    ../features/development/neovim
    ../features/development/zed.nix
  ];
}
