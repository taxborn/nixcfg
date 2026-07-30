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
      fish = {
        interactiveShellInit = ''
          set -gx GPG_TTY (tty)
          set -gx SSH_AUTH_SOCK (gpgconf --list-dirs agent-ssh-socket)
          gpgconf --launch gpg-agent
          gpg-connect-agent updatestartuptty /bye > /dev/null
        '';
        shellAliases = {
          yk-restart = "gpg-connect-agent killagent /bye && gpg-connect-agent \"scd serialno\" \"learn --force\" /bye && gpg --card-status";
        };
      };
    };

    home.packages = with pkgs; [ wofi waybar firefox ];
    home.sessionVariables.NIXOS_OZONE_WL = "1";
    # wayland.windowManager.hyprland = {
    #   enable = true;
    #   # set the Hyprland and XDPH packages to null to use the ones from the NixOS module
    #   package = null;
    #   portalPackage = null;
    # };

    myHome = {
      programs = {
        yubikey.enable = true;
      };
    };
  };
}
