{
  pkgs,
  inputs,
  config,
  ...
}:
let
  sshKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOf8rn+JzRmVc6/4xKOJ4MrmId4xxpYPEgvbCrK18U+N yubikey"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILhCoSFBNavdXRZ8sH1dzGwLO90BfYLNwbbu0yxVgxjf root@carbon"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIO3R84Qt7+WC/pplvm+TNLEreIiBQTiAtbLiYYhucvkL root@helium-01"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFgQtojwvTH5KeMYWNRyIwFtD30Oiepv8qbTUf8kCMLg root@tungsten"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIK2Bj6eF8CLcdxFQZZc7pxpSf/53mbPKRqjJQnK2SXiA root@uranium"
  ];
in
{
  users.users.taxborn = {
    isNormalUser = true;
    # TODO: sops
    initialHashedPassword = "$y$j9T$VyMfknbgYNTja6wNOlXnW.$YkQdA0gJh1VgkFmp185FbsXTvXsKM8/9J1isezUg.37"; # mkpasswd
    shell = pkgs.fish;

    extraGroups = [
      "wheel"
      "networkmanager"
    ];

    openssh.authorizedKeys.keys = sshKeys;

    packages = [ inputs.home-manager.packages.${pkgs.system}.default ];
  };

  programs.fish.enable = true;
  # this step takes a whileeeee so i disable it for now.
  documentation.man.generateCaches = false;

  home-manager = {
    users.taxborn = import ../../../home/taxborn/${config.networking.hostName}.nix;
  };
}
