{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  options.myNixOS.programs.claude-desktop.enable =
    lib.mkEnableOption "claude desktop";

  config = lib.mkIf config.myNixOS.programs.claude-desktop.enable {
    nixpkgs.overlays = [ self.inputs.claude-desktop.overlays.default ];
    environment.systemPackages = [ pkgs.claude-desktop ];
  };
}
