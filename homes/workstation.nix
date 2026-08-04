{
  config,
  pkgs,
  ...
}:
{
  imports = [
    ./default.nix
  ];

  config = {
    programs = {
      claude-code.enable = true;
      fish.shellAliases = {
        yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
        yk-resocket = "gpgconf --kill gpg-agent; systemctl --user restart gpg-agent.socket gpg-agent-ssh.socket gpg-agent-extra.socket";
      };
      obsidian = {
        enable = true;
        cli.enable = true;
      };
      firefox = {
        enable = true;

        # home.stateVersion is below 26.05, so the default is still the legacy
        # `.mozilla/firefox`. The profile here already lives under XDG, so this
        # has to be set explicitly or home-manager manages a directory that does
        # not exist. Any host that adopts this with an existing `~/.mozilla`
        # needs that directory moved by hand first — the option does not migrate
        # it, and native messaging hosts do not follow either.
        configPath = "${config.xdg.configHome}/mozilla/firefox";
      };

      ghostty.enable = true;
      zed-editor.enable = true;
    };

    home.packages = with pkgs; [
      bitwarden-desktop
      spotify
      vesktop
      vlc
    ];

    home.sessionVariables.NIXOS_OZONE_WL = "1";

    myHome = {
      desktop.hyprland.enable = true;

      programs = {
        gpg.agent.enable = true;
        hyprland.enable = true;
        yubikey.enable = true;
      };
    };
  };
}
