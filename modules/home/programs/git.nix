{
  config,
  lib,
  ...
}:
{
  options.myHome.programs.git.enable = lib.mkEnableOption "git version control";

  config = lib.mkIf config.myHome.programs.git.enable {
    programs = {
      # `navigate` rebinds n/N in the pager to jump between files rather than
      # search hits, which is the only way a large diff is readable without
      # scrolling through it linearly.
      delta = {
        enable = true;
        options.navigate = true;
      };

      git = {
        enable = true;
        lfs.enable = true;

        # The primary key in keys/pgp.asc, which gpg.nix installs; gpg picks
        # the signing subkey under it. The private half only exists on the
        # YubiKey, and only a workstation runs an agent with the card in it
        # (`myHome.programs.gpg.agent`), so a commit made on a server cannot
        # sign and git refuses it rather than writing it unsigned.
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

      # github.user is already set above, but gh itself was only ever reachable
      # from inside t3code's wrapper PATH, never from a shell.
      gh = {
        enable = true;
        settings.git_protocol = "ssh";
      };

      lazygit.enable = true;
    };
  };
}
