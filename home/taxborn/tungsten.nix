{ pkgs, ... }:

{
  imports = [
    ./gpg
    ./default.nix
  ];

  home.programs = with pkgs; [
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
      zen.enable = true;
    };
    development = {
      neovim.enable = true;
      zed.enable = true;
    };
  };

  home.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    NIXOS_OZONE_WL = 1; # fixed electron apps blurriness
  };
}
