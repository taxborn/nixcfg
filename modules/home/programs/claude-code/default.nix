{
  config,
  lib,
  pkgs,
  ...
}:
{
  options.myHome.programs.claude-code = {
    enable = lib.mkEnableOption "Claude Code CLI";
  };

  config = lib.mkIf config.myHome.programs.claude-code.enable {
    home.packages = [ pkgs.claude-code ];
  };
}
