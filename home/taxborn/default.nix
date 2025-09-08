{
  imports = [
    ./applications
    ./development
    ./hyprland
    ./packages
    ./shell
    ./gpg
    ./ghostty

    ./fonts.nix
  ];

  home.username = "taxborn";
  home.homeDirectory = "/home/taxborn";
  home.stateVersion = "25.05";
}
