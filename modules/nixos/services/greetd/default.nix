{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myNixOS.services.greetd = {
    enable = lib.mkEnableOption "greetd display manager with ReGreet";

    outputScale = lib.mkOption {
      description = ''
        HiDPI output scale for the cage-wrapped greeter. Drives
        WLR_OUTPUT_SCALE, GDK_SCALE, and XCURSOR_SIZE. Set to e.g. 2
        on a 4K laptop panel; leave at 1 for standard density.
      '';
      type = lib.types.ints.positive;
      default = 1;
    };
  };

  config = lib.mkIf config.myNixOS.services.greetd.enable {
    programs.regreet.enable = true;

    services.greetd = {
      enable = true;
      settings = {
        default_session = {
          command = "${pkgs.cage}/bin/cage -s -- ${lib.getExe config.programs.regreet.package}";
          user = "greeter";
        };
      };
    };

    systemd.services.greetd.environment = {
      WLR_OUTPUT_SCALE = toString config.myNixOS.services.greetd.outputScale;
      GDK_SCALE = toString config.myNixOS.services.greetd.outputScale;
      XCURSOR_SIZE = toString (24 * config.myNixOS.services.greetd.outputScale);
    };

    # Ensure greeter has access to wayland session desktop files
    environment.etc."greetd/environments".text = ''
      hyprland-uwsm.desktop
      hyprland.desktop
    '';
  };
}
