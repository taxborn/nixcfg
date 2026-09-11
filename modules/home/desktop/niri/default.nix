{
  config,
  lib,
  pkgs,
  self,
  ...
}:
let
  cfg = config.myHome.desktop.niri;
in
{
  options.myHome.desktop.niri.enable = lib.mkEnableOption "Niri with Noctalia";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      playerctl
      # Niri starts this on demand for existing X11 applications, including Steam.
      xwayland-satellite
    ];

    xdg.configFile."niri/config.kdl".source = "${self}/modules/home/desktop/niri/config.kdl";

    # A store symlink would make the settings UI read-only. Seed a regular
    # file once, then leave subsequent edits to Noctalia and the user.
    home.activation.seedNoctalia = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [[ ! -e ${lib.escapeShellArg "${config.xdg.configHome}/noctalia/config.toml"} && ! -L ${lib.escapeShellArg "${config.xdg.configHome}/noctalia/config.toml"} ]]; then
        run ${lib.getExe' pkgs.coreutils "install"} -Dm600 \
          ${self}/modules/home/desktop/niri/noctalia.toml \
          ${lib.escapeShellArg "${config.xdg.configHome}/noctalia/config.toml"}
      fi
    '';
  };
}
