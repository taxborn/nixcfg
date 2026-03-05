{ lib, config, ... }:
{
  options.myHome.programs.eza.enable = lib.mkEnableOption "eza";

  config = lib.mkIf config.myHome.programs.eza.enable {
    programs.eza = {
      enable = true;
      icons = "auto";
      extraOptions = [
        "--group"
        "--group-directories-first"
        "--header"
        "--no-permissions"
        "--octal-permissions"
      ];
    };
  };
}
