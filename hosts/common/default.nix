{ pkgs, ... }:
{
  imports = [
    ./users.nix
    ./ssh.nix
    ./gpg.nix
    ./nix.nix
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  networking.networkmanager.enable = true;
  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    neovim
    wget
    git
  ];
  environment.variables.EDITOR = "nvim";
}
