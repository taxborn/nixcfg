{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myNixOS.services.greetd = {
    enable = lib.mkEnableOption "greetd display manager with ReGreet";
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

    # Ensure greeter has access to wayland session desktop files
    environment.etc."greetd/environments".text = ''
      hyprland-uwsm.desktop
      hyprland.desktop
    '';
  };
}
