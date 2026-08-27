{ inputs, ... }:
{
  imports = [ inputs.git-hooks.flakeModule ];

  perSystem =
    { config, ... }:
    {
      # The same hook set runs in two places, so the commit path and
      # `nix flake check` cannot drift: `.git/hooks/pre-commit` over the staged
      # files, and `checks.pre-commit` over the whole tree.
      pre-commit.settings.hooks = {
        # Unused module arguments are the failure mode this catches here — a
        # module that stops reading `osConfig` keeps taking it forever
        # otherwise, because nothing evaluating it ever complains.
        deadnix.enable = true;

        # nixpkgs' `nixfmt` is the RFC 166 formatter, the one the editors in
        # modules/home/programs already call.
        nixfmt.enable = true;

        shellcheck = {
          enable = true;
          # Below `warning` is style advice on scripts that run against paths
          # this repo controls, e.g. SC2012's `ls` in a /sys traversal.
          args = [ "--severity=warning" ];
        };

        statix = {
          enable = true;
          # Whole-tree rather than per-file, which is what lets it read
          # statix.toml from the repo root -- and also what makes this
          # necessary. .gitignore covers .direnv until the moment the hook
          # stashes an edit to it, and statix then follows direnv's symlinks
          # into the store and lints nixpkgs.
          settings.ignore = [ ".direnv" ];
        };
      };

      # `use flake` in .envrc means direnv installs the hooks on the first `cd`
      # into the repo, rather than the install being a step to remember.
      devShells.default = config.pre-commit.devShell;
    };
}
