{ pkgs, ... }:

{
  fonts.fontconfig.enable = true;

  home.packages = with pkgs; [
    # Nerd fonts
    nerd-fonts.jetbrains-mono

    # Accessible fonts
    atkinson-hyperlegible
  ];
}
