{
  imports = [
    ./default.nix
  ];

  features = {
    cli = {
      fish.enable = true;
      tmux.enable = true;
      git.enable = true;
    };
    desktop = {
      ghostty.enable = true;
      hyprland.enable = true;
      etc.enable = true;
      fonts.enable = true;
      zen.enable = true;
      minecraft.enable = true;
    };
    development = {
      neovim.enable = true;
      zed.enable = true;
    };
  };

  # TODO: Is this necessary on an AMDGPU? test when home
  # or whenever I remember...
  home.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    NIXOS_OZONE_WL = 1; # fixed electron apps blurriness
  };
}
