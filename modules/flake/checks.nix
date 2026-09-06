{ self, inputs, ... }:
{
  perSystem = { pkgs, ... }: {
    checks.forgejo-runner-socket = import ../../tests/forgejo-runner-socket.nix { inherit pkgs; };
    checks.restore-runner =
      pkgs.runCommand "restore-runner-checks"
        {
          nativeBuildInputs = [
            pkgs.bash
            pkgs.jq
          ];
          RESTORE_PLAN = pkgs.writeText "restore-plan.json" (builtins.toJSON self.restoreCoverage);
          RESTORE_RUNNER = ../../scripts/restore-all.sh;
        }
        ''
          bash ${../../tests/restore-all.sh}
          touch $out
        '';
    checks.architecture =
      let
        failures = import ../../tests/architecture.nix {
          inherit self;
          lib = inputs.nixpkgs.lib;
        };
      in
      assert inputs.nixpkgs.lib.assertMsg (failures == [ ]) (builtins.toJSON failures);
      pkgs.runCommand "architecture-checks" { } "touch $out";
  };
}
