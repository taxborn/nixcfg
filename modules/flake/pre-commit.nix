{ inputs, ... }:
{
  imports = [ inputs.git-hooks.flakeModule ];

  perSystem =
    { config, pkgs, ... }:
    {
      pre-commit.settings.hooks = {
        deadnix.enable = true;

        nixfmt.enable = true;

        # Pre-push only, so checks.pre-commit never nests a flake check.
        flake-check = {
          enable = true;
          name = "nix flake check --no-build";
          entry = "${pkgs.nix}/bin/nix flake check --no-build";
          stages = [ "pre-push" ];
          pass_filenames = false;
          always_run = true;
        };

        shellcheck = {
          enable = true;
          args = [ "--severity=warning" ];
        };

        statix = {
          enable = true;
          # Without this statix follows direnv's symlinks into the store.
          settings.ignore = [ ".direnv" ];
        };
      };

      devShells.default = config.pre-commit.devShell;
    };
}
