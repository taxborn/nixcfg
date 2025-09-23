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
      userName = "Braxton Fair";
      userEmail = "hello@taxborn.com";

      lfs.enable = true;

      signing.key = "F22AFD6CFD66B874";
      signing.signByDefault = true;

      extraConfig = {
        push.autoSetupRemote = true;
        init.defaultBranch = "main";
      };
    };
  };
}
