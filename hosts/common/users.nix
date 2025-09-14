{
  pkgs,
  inputs,
  ...
}:

{
  programs.fish.enable = true;
  # this step takes a whileeeee so i disable it for now.
  documentation.man.generateCaches = false;

  users.users.taxborn = {
    isNormalUser = true;
    # TODO: sops
    initialHashedPassword = "$y$j9T$VyMfknbgYNTja6wNOlXnW.$YkQdA0gJh1VgkFmp185FbsXTvXsKM8/9J1isezUg.37"; # mkpasswd
    shell = pkgs.fish;
    extraGroups = [
      "wheel"
      "networkmanager"
    ];
  };

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };

    users.taxborn = import ../../home/taxborn;
  };
}
