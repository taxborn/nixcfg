# Niri and Noctalia

Uranium and Tungsten use Niri with Noctalia v5 from the pinned nixpkgs.
The NixOS Noctalia module installs the shell and enables its recommended
NetworkManager, Bluetooth, UPower and power profile services.
Tungsten keeps TuneD with its power-profiles compatibility service; Uranium
uses power-profiles-daemon.
Existing applications and their Catppuccin themes remain enabled. The old
compositor, shell, screenshot script, clipboard picker and idle services are
removed, along with desktop GTK, Qt, icon and cursor themes.

## session

The existing getty autologin runs once per boot on tty1. The Fish login hook
executes `niri-session`, which imports the login environment and starts Niri's
systemd user service. The interactive-shell guard prevents recursion when
`niri-session` opens its own noninteractive login shell. Quitting Niri returns
to the login prompt. There is no greeter or UWSM.

Niri starts Noctalia with `spawn-at-startup`. Xwayland Satellite starts on demand
for X11 applications such as Steam. NixOS supplies the GNOME and GTK portals
for file selection and screen sharing.

## configuration

Edit [`config.kdl`](./config.kdl) for Niri. Home Manager installs it at
`~/.config/niri/config.kdl`. It preserves the existing display setup:

- DP-3 uses 2560×1440 at 165 Hz, scale 1, position 0,0.
- HDMI-A-1 uses 1920×1080 at 60 Hz, scale 1, position 2560,368.
- eDP-1 uses its preferred mode and scale 2.

Noctalia's settings under `~/.config/noctalia/` are writable. Use its settings
UI to experiment. Application-specific Catppuccin themes remain managed by Nix.
Home Manager copies [`noctalia.toml`](./noctalia.toml) to `config.toml` only when
that file does not exist. The initial settings enable authentication prompts
and disable the lockscreen, including locking before suspend. Noctalia's
default idle timers are disabled. Later rebuilds preserve your settings.

## shortcuts

| shortcut | action |
| --- | --- |
| Volume up / down | Adjust the default audio output by 5%, capped at 100% when raising |
| Mute / microphone mute | Toggle the default output / microphone mute |
| Super+Return | Ghostty |
| Super+B | Firefox |
| Super+Z | Zed |
| Super+R | Noctalia launcher |
| MX Master thumb press | Noctalia launcher |
| MX Master thumb swipe left / right | Previous / next workspace |
| Super+Shift+/ | Show shortcut help |
| Super+arrows or H/J/K/L | Focus columns and windows |
| Super+Ctrl+arrows or H/J/K/L | Move columns and windows |
| Super+Shift+arrows or H/J/K/L | Focus a monitor |
| Super+Page Up / Page Down | Change workspace |
| Super+1 through 9 | Focus a workspace |
| Super+Ctrl+1 through 9 | Move a column to a workspace |
| Super+Q | Close a window |
| Super+F / Super+Shift+F | Maximize a column / fullscreen |
| Super+V | Toggle floating |
| Super+O | Overview |
| Super+Shift+E | Quit Niri |

The remaining navigation bindings follow Niri's packaged default config.
Super+R replaces its forward preset-width shortcut; Super+Shift+R still cycles
widths backward. Super+BracketLeft and Super+BracketRight change workspaces for
the mouse gestures. Audio keys use WirePlumber's `wpctl` and work while
locked. No screenshot, lock or playback shortcuts are configured yet.

Validate the compositor file with `niri validate -c modules/home/desktop/niri/config.kdl`.
Build both workstation toplevels before deploying. A successful build cannot
verify physical monitor modes, GPU rendering or application launches in a live
session.
