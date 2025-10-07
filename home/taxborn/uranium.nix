{
  pkgs,
  ...
}:

{
  imports = [
    ./gpg
    ./default.nix
  ];

  home.packages = with pkgs; [
    vlc
    feh
  ];

  features = {
    cli = {
      fish.enable = true;
      git.enable = true;
      tmux.enable = true;
    };
    desktop = {
      etc.enable = true;
      fonts.enable = true;
      ghostty.enable = true;
      hyprland.enable = true;
      minecraft.enable = true;
      obs.enable = true;
      zen.enable = true;
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
