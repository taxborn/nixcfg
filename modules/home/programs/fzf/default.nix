{
  lib,
  pkgs,
  config,
  ...
}:
{
  options.myHome.programs.fzf.enable = lib.mkEnableOption "fzf";

  config = lib.mkIf config.myHome.programs.fzf.enable {
    programs.fzf = {
      enable = true;

      colors = {
        fg = "#cdd6f4";
        "fg+" = "#cdd6f4";
        hl = "#f38ba8";
        "hl+" = "#f38ba8";
        header = "#ff69b4";
        info = "#cba6f7";
        marker = "#f5e0dc";
        pointer = "#f5e0dc";
        prompt = "#cba6f7";
        spinner = "#f5e0dc";
      };

      defaultCommand = "${lib.getExe pkgs.fd} --type=f --hidden --exclude=.git";
      defaultOptions = [
        "--height=30%"
        "--layout=reverse"
        "--info=inline"
      ];
    };
  };
}
