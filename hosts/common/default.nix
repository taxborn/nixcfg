{
  imports = [
    ./users.nix
    ./ssh.nix
    ./gpg.nix
    ./nix.nix
  ];

  i18n.defaultLocale = "en_US.UTF-8";
}
