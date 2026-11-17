{
  lib,
  pkgs,
  ...
}:
{
  programs.fzf = {
    enable = true;
    defaultCommand = "${lib.getExe pkgs.fd} --type=f --hidden --exclude=.git";
    defaultOptions = [
      "--height=30%"
      "--layout=reverse"
      "--info=inline"
    ];
  };
}
