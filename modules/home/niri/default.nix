{
  config,
  lib,
  osConfig,
  pkgs,
  ...
}:
{
  home.packages = with pkgs; [
    playerctl
    xwayland-satellite
  ];

  xdg.configFile."niri/config.kdl".source = ./config.kdl;

  programs.fish.loginShellInit = ''
    # XDG_VTNR leaks into SSH sessions here, so key off the tty instead.
    # niri-session opens a noninteractive login shell to import the environment.
    # Only the original interactive login should launch the session.
    if status is-interactive; and test -z "$WAYLAND_DISPLAY"; and test -z "$SSH_CONNECTION"; and test (tty) = /dev/tty1
        exec ${lib.getExe' osConfig.programs.niri.package "niri-session"}
    end
  '';

  home.activation.seedNoctalia = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [[ ! -e ${lib.escapeShellArg "${config.xdg.configHome}/noctalia/config.toml"} && ! -L ${lib.escapeShellArg "${config.xdg.configHome}/noctalia/config.toml"} ]]; then
      run ${lib.getExe' pkgs.coreutils "install"} -Dm600 \
        ${./noctalia.toml} \
        ${lib.escapeShellArg "${config.xdg.configHome}/noctalia/config.toml"}
    fi
  '';
}
