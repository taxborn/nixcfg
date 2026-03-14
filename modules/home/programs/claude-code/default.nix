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
        # sox allows use of voice-to-text
    home.packages = with pkgs; [ claude-code sox ];
  };
}
