{
  config,
  lib,
  osConfig,
  pkgs,
  self,
  ...
}:
let
  hyprNixOS = osConfig.myNixOS.desktop.hyprland or { };
  laptopMonitor = hyprNixOS.laptopMonitor or null;
  externalMonitors = hyprNixOS.monitors or [ ];
  configuredMonitors = lib.optional (laptopMonitor != null) laptopMonitor ++ externalMonitors;
  monitors = if configuredMonitors == [ ] then [ ",preferred,auto,1" ] else configuredMonitors;

  parseMonitor =
    str:
    let
      parts = lib.splitString "," str;
    in
    {
      output = builtins.elemAt parts 0;
      mode = builtins.elemAt parts 1;
      position = builtins.elemAt parts 2;
      scale = builtins.elemAt parts 3;
    };

  renderMonitor =
    m:
    let
      p = parseMonitor m;
    in
    ''
      hl.monitor({
          output   = "${p.output}",
          mode     = "${p.mode}",
          position = "${p.position}",
          scale    = "${p.scale}",
      })'';

  mapMonitors = lib.concatMapStringsSep "\n" renderMonitor monitors;
in
{
  imports = [
    self.inputs.hyprland.homeManagerModules.default
  ];

  options.myHome.desktop.hyprland = {
    enable = lib.mkEnableOption "Hyprland home-manager configuration";
  };

  config = lib.mkIf config.myHome.desktop.hyprland.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      xwayland.enable = true;
      package = self.inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.hyprland;
      portalPackage = self.inputs.hyprland.packages.${pkgs.stdenv.hostPlatform.system}.xdg-desktop-portal-hyprland;
      systemd.enable = false; # UWSM manages the session
      configType = "lua";
      extraConfig = ''
        ${mapMonitors}

        ${builtins.readFile ./config.lua}
      '';
    };
  };
}
