{
  inputs,
  pkgs,
  config,
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
    ./sops.nix

    inputs.home-manager.nixosModules.home-manager
  ];

  home-manager = {
    useGlobalPkgs = true;
    useUserPackages = true;
    extraSpecialArgs = { inherit inputs; };
  };

  i18n.defaultLocale = "en_US.UTF-8";
  networking.networkmanager.enable = true;

  services.tailscale.enable = true;

  environment.systemPackages = with pkgs; [
    vim
    wget
    git
  ];
  environment.variables.EDITOR = "nvim";
	# environment.variables.CLOUDFLARE_API_KEY = "$(cat ${config.sops.secrets.cloudflare-api-key.path})";
}
