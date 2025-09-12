{
  description = "taxborn's nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # current browser of choice; firefox backend
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # secure boot
    lanzaboote = {
      url = "github:nix-community/lanzaboote/v0.4.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # declarative disk management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # user-level package / file management
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      disko,
      home-manager,
      nixos-hardware,
      lanzaboote,
      ...
    }:
    {
      nixosConfigurations = {
        tungsten = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };

          modules = [
            disko.nixosModules.disko
            nixos-hardware.nixosModules.dell-xps-15-9520-nvidia
            home-manager.nixosModules.home-manager

            ./modules/secure-boot.nix

            ./hosts/tungsten/configuration.nix
          ];
        };

        uranium = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          specialArgs = { inherit inputs; };

          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager

            ./modules/secure-boot.nix

            ./hosts/uranium/configuration.nix
          ];
        };
      };
    };
}
