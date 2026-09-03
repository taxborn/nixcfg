{ inputs, ... }:
{
  # Re-exported so the NixOS module can reach it as
  # `self.packages.<system>.braxton-is`. Every module in this repo takes `self`
  # and none take `inputs` — `modules/flake/hosts.nix` passes only the former in
  # `specialArgs` — and going through here keeps that true rather than widening
  # the argument every module is written against for the sake of one service.
  #
  # It also means `nix build .#braxton-is` works from this repo, which is the
  # smoke test worth running before a deploy: it builds exactly what the unit on
  # Carbon will execute.
  perSystem =
    { system, ... }:
    {
      packages.braxton-is = inputs.braxton-is.packages.${system}.default;
    };
}
