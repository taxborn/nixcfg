{ pkgs, ... }:

{
  imports = [
    ./bluetooth.nix
    ./silent-boot.nix
    ./gpg.nix
    ./nix.nix
    ./ssh.nix
    ./users.nix
    ./virtualisation.nix
    ../../modules/sops.nix
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  networking.networkmanager.enable = true;
  services.tailscale.enable = true;
  # temp workaround for kernel regression
  # https://github.com/NixOS/nixpkgs/issues/438765
  services.tailscale.package = pkgs.tailscale.overrideAttrs { doCheck = false; };

  environment.systemPackages = with pkgs; [
    vim
    pavucontrol
    wget
    git
  ];
  environment.variables.EDITOR = "nvim";
}
