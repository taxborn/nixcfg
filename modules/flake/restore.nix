{ self, inputs, ... }:
let
  lib = inputs.nixpkgs.lib;
  clients = lib.filterAttrs (
    _: host: host.config.myNixOS.services.backups.client.enable
  ) self.nixosConfigurations;
  localReasons = {
    helium.helium = "Helium's own repository uses a local path. Tier 1 covers it on Helium.";
    uranium.local = "Uranium's third copy is on its local SSD. Tier 1 covers it on Uranium.";
  };
in
{
  # The restore runner consumes this evaluated plan. A new local repository
  # needs a stated omission; a new remote backend needs restore-dr support.
  flake.restoreCoverage = lib.mapAttrs (
    host: system:
    lib.mapAttrs (
      name: repo:
      let
        remote = lib.hasPrefix "ssh://" repo.path;
      in
      assert lib.assertMsg (
        repo.label == name
      ) "${host}: restore coverage requires repository names and labels to agree.";
      assert lib.assertMsg (
        !remote
        || builtins.elem name [
          "rsync"
          "helium"
        ]
      ) "${host}/${name}: add this remote backend to restore-dr before including it in restore-all.";
      assert lib.assertMsg (
        remote || (localReasons.${host} or { }) ? ${name}
      ) "${host}/${name}: document why tier 2 omits this local repository.";
      {
        inherit (repo) path remotePath;
        tier1 = true;
        tier2 = remote;
        reason = if remote then null else localReasons.${host}.${name};
      }
    ) system.config.myNixOS.services.backups.client.repositories
  ) clients;

  perSystem = { pkgs, ... }: {
    checks.restore-coverage = pkgs.writeText "restore-coverage.json" (
      builtins.toJSON self.restoreCoverage
    );
  };
}
