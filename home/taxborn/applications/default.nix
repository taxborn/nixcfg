{ pkgs, ... }:

{
  imports = [
    ./ghostty
    ./zed.nix
    ./zen.nix
  ];

  home.packages = with pkgs; [
    obsidian
  ];

  home.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    NIXOS_OZONE_WL = 1; # fixed electron apps blurriness
  };
}
