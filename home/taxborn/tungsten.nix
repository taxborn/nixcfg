{
  imports = [
    ./default.nix

    ../features/cli/fish.nix
    ../features/cli/tmux.nix

    ../features/desktop/ghostty
    ../features/desktop/hyprland
    ../features/desktop/etc.nix
    ../features/desktop/fonts.nix
    ../features/desktop/zen.nix

    ../features/development/neovim
    ../features/development/zed.nix
  ];

  home.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    NIXOS_OZONE_WL = 1; # fixed electron apps blurriness
  };
}
