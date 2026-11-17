{
  lib,
  ...
}:
{
  nix = {
    settings = {
      experimental-features = [
        "flakes"
        "nix-command"
      ];
      # Root-equivalent. Fine only while wheel is one person.
      trusted-users = [
        "root"
        "@wheel"
      ];

      keep-going = true;

      log-lines = 30;

      warn-dirty = false;

      keep-outputs = true;
      keep-derivations = true;

      accept-flake-config = false;

      min-free = lib.mkDefault (1 * 1024 * 1024 * 1024);
      max-free = lib.mkDefault (5 * 1024 * 1024 * 1024);
      # Its key can sign any path, so remove the key with the cache.
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
}
