{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixos-hardware.url = "github:NixOS/nixos-hardware/master";
  };
  outputs = inputs@{ self, nixpkgs, disko, home-manager, nixos-hardware, ... }: {
    nixosConfigurations.tungsten = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        disko.nixosModules.disko
       	nixos-hardware.nixosModules.dell-xps-15-9520-nvidia
       	home-manager.nixosModules.home-manager

        ./hosts/tungsten/configuration.nix
      ];
    };
  };
}
