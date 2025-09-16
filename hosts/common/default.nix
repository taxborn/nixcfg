{ inputs, pkgs, ... }:

{
  imports = [
    ./silent-boot.nix
    ./gpg.nix
    ./nix.nix
    ./ssh.nix
    ./users.nix
    ./virtualisation.nix
    ../../modules/sops.nix

    inputs.home-manager.nixosModules.home-manager
  ];

  i18n.defaultLocale = "en_US.UTF-8";
  networking.networkmanager.enable = true;

  services.tailscale.enable = true;

  hardware.bluetooth.enable = true;
  services.blueman.enable = true;
  environment.systemPackages = with pkgs; [
    vim
    pavucontrol
    wget
    git
  ];
  environment.variables.EDITOR = "nvim";
}
