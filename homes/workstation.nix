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
