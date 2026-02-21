{
  config,
  lib,
  pkgs,
  ...
}: {
  options.myNixOS.programs.gimp.enable = lib.mkEnableOption "GIMP image editor";

  config = lib.mkIf config.myNixOS.programs.gimp.enable {
    environment.systemPackages = [ pkgs.gimp ];
  };
}
