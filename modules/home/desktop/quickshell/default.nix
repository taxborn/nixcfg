{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.myHome.desktop.quickshell;

  # `qs -c <name>` selects a directory under ~/.config/quickshell, so this name
  # is both the config directory and the argument every IPC call needs.
  configName = "taxborn";

  # The QML calls its helpers by bare name: `python3` runs stats.py, the
  # launcher wraps Terminal=true entries in `ghostty`, and the volume chip opens
  # `pavucontrol`. A user unit only has the PATH the session manager imported at
  # login, which is not a promise any of the three are on. Bind them to the
  # binary instead of spelling store paths into QML that also has to run under
  # `qs -p` from a checkout.
  quickshell = pkgs.symlinkJoin {
    name = "quickshell-with-shell-tools";
    paths = [ pkgs.quickshell ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    # `qs` and `quickshell` are two copies of the same program, not a symlink
    # pair, so wrapping one leaves the other as a trap.
    postBuild = ''
      for entry in qs quickshell; do
        wrapProgram $out/bin/$entry \
          --suffix PATH : ${
            lib.makeBinPath [
              pkgs.python3
              pkgs.ghostty
              pkgs.pavucontrol
            ]
          }
      done
    '';
    # symlinkJoin does not inherit meta, and `lib.getExe` on the result is what
    # home-manager writes into the unit's ExecStart.
    meta.mainProgram = "qs";
  };
in
{
  options.myHome.desktop.quickshell.enable = lib.mkEnableOption "Quickshell desktop shell";

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = !config.myHome.programs.waybar.enable && !config.myHome.services.mako.enable;
        message = ''
          Quickshell draws the bar and claims org.freedesktop.Notifications.
          Waybar duplicates the bar and Mako takes the bus name first, so
          neither can run beside it.
        '';
      }
    ];

    programs.quickshell = {
      enable = true;
      package = quickshell;
      configs.${configName} = ./shell;
      activeConfig = configName;
      systemd = {
        enable = true;
        target = "hyprland-session.target";
      };
    };

    # Home Manager's generated unit only orders itself After the target and is
    # Wanted by it. Add the same lifetime Mako has: a shell with no compositor
    # has nothing to draw on, and one left running holds the notification bus
    # name against the next session.
    systemd.user.services.quickshell.Unit = {
      BindsTo = "hyprland-session.target";
      PartOf = "graphical-session.target";
    };

    # Moved here from the Waybar module with the bar. nm-applet exposes
    # NetworkManager over StatusNotifierItem (nixpkgs builds it against
    # libayatana-appindicator, so it registers one without --indicator), which
    # is what puts NetworkManager in the Quickshell tray. It publishes bare icon
    # *names* with an empty IconThemePath, so the tray resolves them out of the
    # session icon theme -- see gtk.enable in homes/workstation.nix.
    services.network-manager-applet.enable = true;
  };
}
