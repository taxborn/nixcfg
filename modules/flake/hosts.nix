{ self, inputs, ... }:

{
  flake.nixosConfigurations =
    let
      modules = self.nixosModules;
    in
    inputs.nixpkgs.lib.genAttrs
      [
        "argon"
        "carbon"
        "helium"
        "tungsten"
        "uranium"
      ]
      (
        host:
        inputs.nixpkgs.lib.nixosSystem {
          modules = [
            ../../hosts/${host}
            inputs.agenix.nixosModules.default
            inputs.disko.nixosModules.disko
            inputs.home-manager.nixosModules.home-manager
            inputs.lanzaboote.nixosModules.lanzaboote

            modules.hardware
            modules.nixos
            modules.users
            modules.snippets

            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs = { inherit self; };
                backupFileExtension = "backup";
              };

              nixpkgs.config.allowUnfree = true;

              # Was set inside the Intel CPU module, which made the platform a
              # property of the CPU vendor: the first non-Intel host would have
              # come up with no `hostPlatform` at all and failed to evaluate for
              # a reason pointing nowhere near the cause. `systems` in parts.nix
              # already says this is the only architecture built here.
              nixpkgs.hostPlatform = inputs.nixpkgs.lib.mkDefault "x86_64-linux";
            }
          ];

          specialArgs = { inherit self; };
        }
      );
}
