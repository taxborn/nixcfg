{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myNixOS.programs.nix.enable = lib.mkEnableOption "sane nix configuration";

  config = lib.mkIf config.myNixOS.programs.nix.enable {
    nix = {
      settings = {
        experimental-features = [
          "flakes"
          "nix-command"
        ];
        # `@wheel` can set substituters and import unsigned paths, which is
        # root-equivalent. Fine for a single-admin fleet, wrong if wheel ever
        # holds anyone else.
        trusted-users = [
          "root"
          "@wheel"
        ];

        # Keep building the rest of a closure after one derivation fails, so a
        # build left running while away from the desk still fills the cache.
        keep-going = true;

        # The default of 10 lines cuts most failures off before the useful part.
        log-lines = 30;

        # Every `nix build` against a working tree under edit prints this.
        warn-dirty = false;

        # Keep the build inputs and outputs a dev shell was realised from, so
        # a garbage collection does not delete what direnv's GC roots point at
        # the next time the shell is entered. Not free: it holds disk.
        keep-outputs = true;
        keep-derivations = true;

        # A flake config can set substituters and post-build hooks. Nix would
        # prompt, but a prompt is easy to accept in passing.
        accept-flake-config = false;

        # Free space thresholds. Defaults suit a small disk, a host that builds
        # large closures overrides them.
        min-free = lib.mkDefault (1 * 1024 * 1024 * 1024);
        max-free = lib.mkDefault (5 * 1024 * 1024 * 1024);
        # A third-party cache. Its key is trusted to sign any path this host
        # will accept, so removing the cache means removing the key too.
        substituters = [
          "https://cache.nixos.org"
          "https://nix-community.cachix.org"
        ];
        trusted-public-keys = [
          "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
          "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        ];
      };

      gc = {
        automatic = true;
        options = "--delete-older-than 3d";
        persistent = true;
        randomizedDelaySec = "60min";
      };

      extraOptions = ''
        download-buffer-size = ${toString (256 * 1024 * 1024)}
      '';

      optimise = {
        automatic = true;
        persistent = true;
        randomizedDelaySec = "60min";
      };
    };

    programs.nix-ld.enable = true;

    environment.systemPackages = with pkgs; [
      nil
      nixd
      nixfmt
    ];
  };
}
