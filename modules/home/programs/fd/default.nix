{ lib, config, ... }:
{
  options.myHome.programs.fd.enable = lib.mkEnableOption "fd";

  config = lib.mkIf config.myHome.programs.fd.enable {
    programs.fd = {
      enable = true;
      hidden = true;
      ignores = [
        ".git/"
      ];
    };
  };
}
