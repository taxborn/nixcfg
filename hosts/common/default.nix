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
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  networking.networkmanager.enable = true;
  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    neovim
    pavucontrol
    wget
    git
  ];
  environment.variables.EDITOR = "nvim";
}
