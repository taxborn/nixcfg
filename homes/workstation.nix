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
      firefix = {
        enable = true;
        configPath = "${config.xdg.configHome}/mozilla/firefox"
      };
    };

    home.packages = with pkgs; [
      bitwarden-desktop
      firefox
      spotify
      vesktop
      vlc
    ];

    programs = {
      zed-editor.enable = true;
      ghostty.enable = true;
    };

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
