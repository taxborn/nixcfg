{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.myHome.programs.obs.enable = lib.mkEnableOption "obs studio";

  config = lib.mkIf config.myHome.programs.obs.enable {
    home.packages = [
      pkgs.ledger-live-desktop
    ];
  };
}
