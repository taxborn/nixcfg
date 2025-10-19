{ lib, config, ... }:
with lib;
let
  cfg = config.features.cli.git;
in
{
  options.features.cli.git.enable = mkEnableOption "enable git configuration";

  config = mkIf cfg.enable {
    programs.git = {
      enable = true;
      settings = {
        user.name = "Braxton Fair";
        user.email = "hello@taxborn.com";
        push.autoSetupRemote = true;
        init.defaultBranch = "main";
      };

      lfs.enable = true;

      signing.key = "F22AFD6CFD66B874";
      signing.signByDefault = true;
    };
  };
}
