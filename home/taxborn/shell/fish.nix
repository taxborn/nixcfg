{ pkgs, ... }:

{
  programs.fish = {
    enable = true;
    interactiveShellInit = ''
      set -gx PATH $PATH $HOME/bin $HOME/.local/bin

      set -gx GPG_TTY (tty)
      set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
      gpgconf --launch gpg-agent
      gpg-connect-agent updatestartuptty /bye > /dev/null
    '';
    shellAliases = {
      nix-rb = "sudo nixos-rebuild switch --flake /home/taxborn/dotfiles"; # TODO: I think there is an env variable to set the dir
      yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
    };
  };
}
