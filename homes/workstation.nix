{
  pkgs,
  ...
}:
{
  imports = [
    ./default.nix
  ];

  config = {
    programs = {
      # No `GPG_TTY`/`SSH_AUTH_SOCK`/`gpgconf --launch` init here any more.
      # home-manager's gpg-agent module emits all three, and — unlike the hand
      # written version this replaces — its `SSH_AUTH_SOCK` line is guarded on
      # `SSH_CONNECTION`, so it leaves a forwarded agent alone. Setting it
      # unconditionally meant an ssh session *into* a workstation lost the
      # forwarded yubikey the moment fish started, and pointed at the local
      # agent, which on the machine you are not sitting at holds no card.
      fish.shellAliases = {
        yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";

        # For after someone ssh'd *into* this machine with gpg forwarding on. A
        # forwarded session binds its own socket over `S.gpg-agent` and removes
        # it on the way out, which leaves this host's socket units listening on
        # a path that no longer exists — local gpg then talks to an agent it
        # spawned itself, outside systemd, and the cached PIN is not where the
        # units think it is. Nothing notices until it behaves oddly; this puts
        # it back.
        yk-resocket = "gpgconf --kill gpg-agent; systemctl --user restart gpg-agent.socket gpg-agent-ssh.socket gpg-agent-extra.socket";
      };
      claude-code.enable = true;
    };

    home.packages = with pkgs; [
      firefox
    ];

    programs = {
      zed-editor.enable = true;
      ghostty.enable = true;
    };

    home.sessionVariables.NIXOS_OZONE_WL = "1";

    myHome = {
      desktop.hyprland.enable = true;

      programs = {
        # The card lives here, so this is where the agent runs — and what every
        # other host borrows over a forwarded socket.
        gpg.agent.enable = true;
        # Still the package set (wofi, waybar, hyprlock, hypridle) that the
        # `desktop.hyprland` lua config drives; only the config moved.
        hyprland.enable = true;
        yubikey.enable = true;
      };
    };
  };
}
