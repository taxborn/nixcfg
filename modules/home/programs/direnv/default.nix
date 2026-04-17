{ lib, config, ... }:
{
  options.myHome.programs.direnv.enable = lib.mkEnableOption "direnv";

  config = lib.mkIf config.myHome.programs.direnv.enable {
    programs.direnv = {
      enable = true;
      enableFishIntegration = true;
      nix-direnv.enable = true;
    };
  };
}
