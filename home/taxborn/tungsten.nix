{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    ./applications
    ./desktop
    ./development
    ./fonts
    ./packages
    ./shell
    ./system
    ./gpg
    ./ghostty
  ];
}
