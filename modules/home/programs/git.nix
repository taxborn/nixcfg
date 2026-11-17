{
  lib,
  pkgs,
  self,
  osConfig,
  ...
}:
{
  programs = {
    delta = {
      enable = true;
      options.navigate = true;
    };

    git = {
      enable = true;
      lfs.enable = true;

      # The key is on the YubiKey, so servers refuse to commit rather than skip signing.
      signing.key = osConfig.homelab.owner.gpgKey;
      signing.signByDefault = true;

      settings = {
        color.ui = true;
        github.user = "taxborn";

        push.autoSetupRemote = true;
        init.defaultBranch = "main";

        user = {
          inherit (osConfig.homelab.owner) name email;
        };
      };
    };

    gh = {
      enable = true;
      settings.git_protocol = "ssh";
    };

    lazygit.enable = true;
  };

  catppuccin.sources.lazygit = pkgs.runCommand "catppuccin-lazygit-migrated" { } ''
    cp -r ${self.packages.${pkgs.stdenv.hostPlatform.system}.catppuccin-lazygit} $out
    chmod -R u+w $out
    for f in $out/*/*.yml; do
      ${lib.getExe pkgs.yq-go} -i \
        '.gui.theme.authorColors = .gui.authorColors | del(.gui.authorColors)' "$f"
    done
  '';
}
