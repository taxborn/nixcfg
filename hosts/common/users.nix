{ pkgs, ... }:

{
  users.users.taxborn = {
    isNormalUser = true;
    # TODO: sops
    initialHashedPassword = "$y$j9T$VyMfknbgYNTja6wNOlXnW.$YkQdA0gJh1VgkFmp185FbsXTvXsKM8/9J1isezUg.37"; # mkpasswd
    extraGroups = [ "wheel" "networkmanager" ];
    packages = with pkgs; [ ];
  };

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.taxborn = import ../../home/taxborn.nix;
}
