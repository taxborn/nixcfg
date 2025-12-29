{ lib, ... }:
{
  imports = [
    ./base
    ./desktop
    ./profiles
    ./programs
    ./services
  ];

  options.myNixOS.FLAKE = lib.mkOption {
    type = lib.types.str;
    default = "git+https://git.mischief.town/nix-infra/nixcfg";
    description = "Default flake URL for this NixOS configuration.";
  };
}
