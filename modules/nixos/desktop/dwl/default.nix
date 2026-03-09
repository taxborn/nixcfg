{
  config,
  lib,
  ...
}:
{
  options.myNixOS.desktop.dwl = {
    enable = lib.mkEnableOption "dwl desktop environment";
  };

  config = lib.mkIf config.myNixOS.desktop.dwl.enable {
    home-manager.sharedModules = [
      {
        myHome.desktop.dwl.enable = true;
      }
    ];

    programs.dwl = {
      enable = true;
      extraSessionCommands = ''
        export XDG_CURRENT_DESKTOP=wlroots
        export XDG_SESSION_TYPE=wayland
      '';
    };

    system.nixos.tags = [ "dwl" ];
    myNixOS.desktop.enable = true;
  };
}
