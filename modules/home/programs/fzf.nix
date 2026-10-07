{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.myHome.programs.fzf;
in
{
  options.myHome.programs.fzf.enable = lib.mkEnableOption "fzf";

  config = lib.mkIf cfg.enable {
    programs.fzf = {
      enable = true;
      defaultCommand = "${lib.getExe pkgs.fd} --type=f --hidden --exclude=.git";
      defaultOptions = [
        "--height=30%"
        "--layout=reverse"
        "--info=inline"
      ];
    };
  };
}
