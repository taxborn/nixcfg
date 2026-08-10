{ inputs, ... }:
{
  # Re-exported so the NixOS module can reach it as
  # `self.packages.<system>.taxborn-com`. Every module in this repo takes `self`
  # and none take `inputs` — `modules/flake/hosts.nix` passes only the former in
  # `specialArgs` — and going through here keeps that true rather than widening
  # the argument every module is written against for the sake of one service.
  #
  # It also means `nix build .#taxborn-com` works from this repo, which is the
  # smoke test worth running before a deploy: it builds exactly what the unit on
  # Carbon will execute.
  perSystem =
    { system, ... }:
    {
      packages.taxborn-com = inputs.taxborn-com.packages.${system}.default;
    };
}
