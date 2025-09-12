{ pkgs, ... }:

{
  imports = [
    ./ghostty
    ./neovim
    ./zed.nix
    ./zen.nix
  ];

  home.packages = with pkgs; [
    discord
    obsidian
    spotify
  ];

  programs.zoxide = {
    enable = true;
    enableFishIntegration = true;
  };

  programs.yazi.enable = true;
  programs.obs-studio.enable = true;
  programs.lazygit.enable = true;
  programs.bat.enable = true;

  home.sessionVariables = {
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    NIXOS_OZONE_WL = 1; # fixed electron apps blurriness
  };
}
