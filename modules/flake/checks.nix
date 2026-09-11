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
          RESTORE_KEYS = ../../scripts/restore-keys.sh;
          RESTORE_DR = ../../scripts/restore-dr.sh;
        }
        ''
          mkdir runner recipes
          (cd runner && bash ${../../tests/restore-all.sh})
          (cd recipes && bash ${../../tests/restore-recipes.sh})
          touch $out
        '';
    # stats.py is a persistent process behind the Quickshell dashboard, so its
    # counter math never fails loudly: a wrong number just renders. Run its
    # regressions where the rest of the tree is checked.
    checks.quickshell-stats =
      pkgs.runCommand "quickshell-stats-checks"
        {
          nativeBuildInputs = [ pkgs.python3 ];
          PYTHONPATH = ../home/desktop/quickshell/shell;
        }
        ''
          python3 -m unittest discover -s ${../home/desktop/quickshell} -p 'test_*.py'
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
