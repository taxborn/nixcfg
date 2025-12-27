{
  inputs,
  pkgs,
  ...
}:

{
  imports = [
    ./extraServices
    ./users

    ./silent-boot.nix
    ./gpg.nix
    ./nix.nix
    ./ssh.nix

    inputs.home-manager.nixosModules.home-manager
    inputs.agenix.nixosModules.default
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
  };

  i18n.defaultLocale = "en_US.UTF-8";
  networking.networkmanager.enable = true;

  services.tailscale.enable = true;
  environment.localBinInPath = true;

  environment.systemPackages = with pkgs; [
    vim
    neovim
    wget
    git
  ];
  environment.variables.EDITOR = "nvim";
}
