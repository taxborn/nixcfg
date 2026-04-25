{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.programs.bitwarden = {
    enable = lib.mkEnableOption "Bitwarden password manager with rofi integration";
  };

  config = lib.mkIf config.myHome.programs.bitwarden.enable {
    home.packages = with pkgs; [
      bitwarden-desktop
    ];
  };
}
