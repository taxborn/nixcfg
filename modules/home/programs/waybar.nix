{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  isLaptop = osConfig.myHardware.profiles.laptop.enable or false;

  # Waybar 0.15.0 switches workspaces by sending the legacy `dispatch workspace
  # <id>` command over Hyprland's IPC socket. Under Hyprland's Lua config
  # (configType = "lua", 0.55+) that payload is evaluated as Lua, so it fails
  # with `')' expected near '<id>'` and clicks silently do nothing. Fixed
  # upstream in Waybar PR #5013 (uses `hl.dsp.focus({...})`), which is merged to
  # master but not yet in a tagged release, so pin the merge commit until a
  # release ships it. See https://github.com/Alexays/Waybar/issues/5008
  # cava is disabled because nixpkgs copies its pinned cava subproject into a
  # versioned dir that no longer matches this commit's cava.wrap; we don't use
  # the cava (audio visualizer) module anyway.
  waybarLuaFix = (pkgs.waybar.override { cavaSupport = false; }).overrideAttrs (old: {
    version = "0.15.0-unstable-2026-07-21";
    src = pkgs.fetchFromGitHub {
      owner = "Alexays";
      repo = "Waybar";
      rev = "30610d3b68f109e950d924bc7d9c42b8cbbc5df8";
      hash = "sha256-pSbVf9mMWazkaTgNM0X4pfkIS/6AzoAfs7YTS27udOE=";
    };
    # This untagged commit still self-reports "v0.15.0", so nixpkgs'
    # versionCheckHook would fail against the version string above.
    doInstallCheck = false;

    # This commit adds a `wwan` meson feature that the packaged release doesn't
    # have, so nixpkgs' flag list doesn't cover it. nixpkgs defaults
    # `auto_features` to "enabled", which turns it on and makes the mm-glib
    # (ModemManager) dependency mandatory. We have no WWAN module in the bar.
    mesonFlags = old.mesonFlags ++ [ "-Dwwan=disabled" ];

    # The inhibitor module takes the process-wide *shared* system bus from
    # g_bus_get_sync() but closes it in its destructor instead of dropping its
    # reference. home-manager reloads Waybar (SIGUSR2, see X-Reload-Triggers on
    # the unit) on every switch that touches the config or CSS, which destroys
    # the module and leaves the shared connection closed for the whole process;
    # GDBus then hands the recreated module that same cached, closed connection,
    # so every logind Inhibit call fails with "The connection is closed" and
    # clicking the module silently does nothing until Waybar is restarted.
    # Still unfixed on upstream master as of this pin, so patch it here.
    postPatch = (old.postPatch or "") + ''
      substituteInPlace src/modules/inhibitor.cpp \
        --replace-fail 'g_dbus_connection_close_sync(connection, nullptr, &error);' \
                       'g_object_unref(connection);'
    '';
  });
in
{
  options.myHome.programs.waybar.enable = lib.mkEnableOption "Waybar status bar";

  config = lib.mkIf config.myHome.programs.waybar.enable {
    programs.waybar = {
      enable = true;
      package = waybarLuaFix;
      systemd.enable = true;

      settings = {
        mainBar = {
          position = "top";
          margin = "8 8 0 8";
          modules-left = [
            "hyprland/workspaces"
            "tray"
          ];
          modules-center = [
            "clock"
          ];
          modules-right = [
            "inhibitor"
            "pulseaudio"
          ]
          ++ lib.optional isLaptop "battery"
          ++ [
            "memory"
            "cpu"
          ];
          clock = {
            calendar = {
              mode = "year";
              mode-mon-col = 4;
              weeks-pos = "left";
              format = {
                months = "<span color='#cba6f7'><b>{}</b></span>";
                days = "<span color='#cdd6f4'><b>{}</b></span>";
                weeks = "<span color='#cba6f7'><i><b>W{}</b></i></span>";
                weekdays = "<span color='#cba6f7'><b>{}</b></span>";
                today = "<span color='#a6e3a1'><b>{}</b></span>";
              };
            };
            format = "{:%R} ";
            format-alt = "{:%A, %B %d, %Y (%T)} 󰃰";
            tooltip = "true";
            tooltip-format = "<span>{:%F %T (day %j)}</span>\n\n{calendar}";
            interval = 1;
          };
          inhibitor = {
            what = "idle";
            format = " {icon} ";
            format-icons = {
              activated = "";
              deactivated = "";
            };
          };
          battery = {
            bat = "BAT0";
            interval = 60;
            states = {
              warning = 30;
              critical = 15;
            };
            events = {
              on-discharging-warning = "notify-send -u normal 'Low Battery'";
              on-discharging-critical = "notify-send -u critical 'Very Low Battery'";
              on-charging-100 = "notify-send -u normal 'Battery Full!'";
              on-discharging = "notify-send -u normal 'Power Switch' Discharging";
              on-charging = "notify-send -u normal 'Power Switch' Charging'";
            };
            format = "{capacity}% {icon}";
            format-icons = [
              ""
              ""
              ""
              ""
              ""
            ];
            max-length = 25;
          };
          pulseaudio = {
            format = "{volume}% {icon}";
            format-bluetooth = "{volume}% {icon}";
            format-muted = "";
            format-icons = {
              default = [
                ""
                ""
              ];
            };
            on-click = "pavucontrol";
          };
          tray = {
            icon-size = 16;
            spacing = 10;
          };
        };
      };
      style = ''
        * {
          font-family: "JetBrainsMonoNL NFM";
          font-size: 14px;
          /* some reset */
          border: none;
          border-radius: 0px;
          padding: 0;
          margin: 0;
        }

        window#waybar {
          background-color: transparent;
          color: #cdd6f4;
          transition-property: background-color;
          transition-duration: 0.5s;
        }

        tooltip {
          background-color: #1e1e2e;
          opacity: 0.9;
          border: 2px solid;
          border-color: #cba6f7;
          border-radius: 4px;
          color: #cdd6f4;
        }

        .modules-left,
        .modules-center,
        .modules-right {
          background-color: #1e1e2e;
          border-radius: 8px;
          padding: 2px 8px;
        }

        #workspaces button {
          color: #cdd6f4;
          padding: 0 6px;
          margin: 0;
        }
        #workspaces button.active {
          color: #cba6f7;
        }

        /* space the tray away from the workspace numbers */
        #tray {
          margin-left: 8px;
        }

        /* gaps live *between* the right-side modules, so the group stays
           evenly inset within the pill (last child gets no trailing margin) */
        #pulseaudio,
        #inhibitor,
        #battery,
        #memory {
          margin-right: 12px;
        }
      '';
    };

    # Feed the Waybar tray: nm-applet exposes NetworkManager via the
    # StatusNotifierItem protocol (nixpkgs builds it against
    # libayatana-appindicator, so it registers one without --indicator). Runs as
    # a graphical-session user service, so it's only meaningful with the tray.
    # It publishes bare icon *names* with an empty IconThemePath, so Waybar has
    # to resolve them out of the session icon theme -- see gtk.enable in
    # homes/workstation.nix.
    services.network-manager-applet.enable = true;
  };
}
