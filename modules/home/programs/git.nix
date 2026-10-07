{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myHome.programs.git;
in
{
  options.myHome.programs.git.enable = lib.mkEnableOption "git version control";

  config = lib.mkIf cfg.enable {
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

          # Cloudflare rejects LFS uploads over 100 MB. Forgejo hands back
          # upload hrefs on its public name whatever `lfs.url` says, so they
          # have to be rewritten onto the tailnet vhost.
          lfs.transfer.enablehrefrewrite = true;
          url."https://${config.mySnippets.biscuits-at.networkMap.forgejo.sshDomain}/".insteadOf =
            "https://${config.mySnippets.biscuits-at.networkMap.forgejo.domain}/";

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

    # The upstream theme still has `gui.authorColors` at the top level. Lazygit
    # migrates it to `gui.theme.authorColors` on every start and tries to write
    # the result back, which fails on the read-only store path that
    # LG_CONFIG_FILE points at. Migrate it at build time instead. Drop this once
    # catppuccin/lazygit ships the new layout.
    catppuccin.sources.lazygit = pkgs.runCommand "catppuccin-lazygit-migrated" { } ''
      cp -r ${(import self.inputs.catppuccin { inherit pkgs; }).packages.lazygit} $out
      chmod -R u+w $out
      for f in $out/*/*.yml; do
        ${lib.getExe pkgs.yq-go} -i \
          '.gui.theme.authorColors = .gui.authorColors | del(.gui.authorColors)' "$f"
      done
    '';
  };
}
