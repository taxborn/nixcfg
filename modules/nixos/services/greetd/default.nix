{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myNixOS.services.greetd;

  swayConfig = lib.optionalString (cfg.primaryOutput != null) (
    pkgs.writeText "greetd-sway-config" ''
      output * disable
      output ${cfg.primaryOutput} enable scale ${toString cfg.outputScale}
      exec "${lib.getExe config.programs.regreet.package}; ${pkgs.sway}/bin/swaymsg exit"
    ''
  );

  sessionCommand =
    if cfg.primaryOutput != null
    then "${pkgs.sway}/bin/sway --config ${swayConfig}"
    else "${pkgs.cage}/bin/cage -s -- ${lib.getExe config.programs.regreet.package}";
in
{
  options.myNixOS.services.greetd = {
    enable = lib.mkEnableOption "greetd display manager with ReGreet";

    outputScale = lib.mkOption {
      description = ''
        HiDPI output scale for the greeter. On multi-monitor setups (sway mode)
        this sets the scale of the primary output. On single-monitor cage mode it
        drives WLR_OUTPUT_SCALE, GDK_SCALE, and XCURSOR_SIZE.
      '';
      type = lib.types.ints.positive;
      default = 1;
    };

    primaryOutput = lib.mkOption {
      description = ''
        Wayland output name to show the greeter on (e.g. "DP-3"). When set,
        sway is used as the compositor with all other outputs disabled, which
        fixes greeter spanning across multiple monitors. Leave null for
        single-monitor setups to keep using cage.
      '';
      type = lib.types.nullOr lib.types.str;
      default = null;
    };
  };

  config = lib.mkIf cfg.enable {
    programs.regreet = {
      enable = true;
      settings = {
        background = {
          path = "${../../../../assets/wallpapers/island.jpeg}";
          fit = "Cover";
        };
      };
      extraCss = ''
        window {
          background-color: black;
        }
        picture {
          opacity: 0.65;
        }
      '';
    };

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = sessionCommand;
          user = "greeter";
        };
      };
    };

    systemd.services.greetd.environment = lib.mkIf (cfg.primaryOutput == null) {
      WLR_OUTPUT_SCALE = toString cfg.outputScale;
      GDK_SCALE = toString cfg.outputScale;
      XCURSOR_SIZE = toString (24 * cfg.outputScale);
    };

    # Ensure greeter has access to wayland session desktop files
    environment.etc."greetd/environments".text = ''
      hyprland-uwsm.desktop
    '';
  };
}
