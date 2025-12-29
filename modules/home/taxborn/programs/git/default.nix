{
  config,
  lib,
  pkgs,
  ...
}: {
  options.myHome.taxborn.programs.git.enable = lib.mkEnableOption "git version control";

  config = lib.mkIf config.myHome.taxborn.programs.git.enable {
    home.packages = [pkgs.wl-clipboard];

    programs = {
      delta = {
        enable = true;
        enableGitIntegration = true;
      };

      git = {
        enable = true;
        lfs.enable = true;

        signing.key = "F22AFD6CFD66B874";
        signing.signByDefault = true;

        settings = {
          color.ui = true;
          github.user = "taxborn";

          push.autoSetupRemote = true;
          init.defaultBranch = "main";

          user = {
            name = "Braxton Fair";
            email = "hello@taxborn.com";
          };
        };
      };

      lazygit.enable = true;
    };
  };
}
