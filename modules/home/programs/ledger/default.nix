{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.myHome.programs.ledger.enable = lib.mkEnableOption "ledger live";

  config = lib.mkIf config.myHome.programs.ledger.enable {
    home.packages = [
      pkgs.ledger-live-desktop
    ];
  };
}
