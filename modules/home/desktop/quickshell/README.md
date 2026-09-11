# quickshell

The desktop shell for Tungsten and Uranium: bar, launcher, notifications and
machine dashboard in one Quickshell process. Catppuccin Mocha, floating panels,
rounded buttons and a few pastel accents. It replaces Waybar and Mako, and
leaves the rest of the Hyprland configuration alone, including monitor layouts,
window rules, wallpaper, clipboard picker, lock screen and idle handling.

`myHome.desktop.quickshell.enable` is set by the Hyprland desktop module, so
enabling that enables this. The module links `shell/` to
`~/.config/quickshell/taxborn` and starts `quickshell.service` from
`hyprland-session.target`, which is also what stops it when the session ends.

Quickshell draws the bar and claims `org.freedesktop.Notifications`, so
`myHome.programs.waybar` and `myHome.services.mako` cannot be enabled beside it.
The module asserts that rather than leaving two bars to fight over the tray.

## Commands

The shell answers IPC on the running session:

```sh
qs -c taxborn ipc call shell launcher
qs -c taxborn ipc call shell dashboard
qs -c taxborn ipc call shell notifications
qs -c taxborn ipc call shell music
qs -c taxborn ipc call shell close
```

**Super+R** is the launcher call above, bound in
[`../hyprland/config/keybinds.lua`](../hyprland/config/keybinds.lua).

## What is here

- A bar on every display with ten workspaces, tray menus, clock, CPU, RAM,
  network download rate, idle inhibitor, volume, battery and notification count.
  RAM and network move to the dashboard on narrower screens. The clock joins
  the right section when there is not room for a separate middle section.
- A pulsing green blip beside the clock while Spotify is playing. Click it for
  album art, track/artist/album details, a live audio visualizer, and previous,
  play/pause and next controls. The panel stays open when paused; its Music tab
  also lets you reopen it while Spotify is paused.
- Application search by name, description and keywords. Arrow keys select,
  Enter launches, Escape closes. Terminal applications open in Ghostty.
- Notification toasts and an inbox with actions, dismissal, clear-all and
  do-not-disturb. The inbox holds up to 50 notifications in memory. It survives
  QML reloads through Quickshell's notification tracking, but not a process restart.
- A scrollable machine dashboard with per-core CPU load, memory, swap, filesystem
  usage, network transfer rates, GPU utilization and VRAM where exposed, hardware
  temperatures, uptime, kernel version and battery status.

Click the CPU, RAM, network or clock to open the dashboard. Click the bell for
the inbox, or right-click it to toggle do-not-disturb. The cup toggles idle
inhibition; manual locking still works. Click volume for pavucontrol, right-click
to mute, or scroll to change volume, capped at 100%.

Notifications appear on the focused display. Popups also open on the display
whose bar you clicked. The launcher shortcut opens on the focused display.
Click outside a popup or press Escape to close it.

## Editing it

The linked configuration is a store path, so the running shell cannot be edited
in place. Stop the unit and run the checkout instead, which is where Quickshell's
QML file watching earns its keep:

```sh
systemctl --user stop quickshell
qs -p modules/home/desktop/quickshell/shell
```

`Ctrl+C`, then `systemctl --user start quickshell` to go back to the built
configuration. A rebuild is what makes an edit permanent.

| File | Change here |
| --- | --- |
| `shell/Theme.qml` | Colours, font, corner radius, bar height and motion timings |
| `shell/Overlay.qml` | Popup card, its slide in from the top edge and the tab strip |
| `shell/Bar.qml` | Bar contents, spacing and responsive layout |
| `shell/Launcher.qml` | Search, application rows and terminal choice |
| `shell/Dashboard.qml` | Machine details |
| `shell/Spotify.qml`, `shell/MusicBlip.qml`, `shell/NowPlaying.qml` | Spotify detection, clock blip and player panel |
| `shell/AudioVisualizer.qml` | Live Spotify amplitude history |
| `shell/NoticeCard.qml`, `shell/Inbox.qml`, `shell/Toasts.qml` | Notification appearance |
| `shell/ShellState.qml` | Which popup is open, on which screen, and IPC |
| `shell/Notices.qml` | Notification lifecycle, toast expiry and do-not-disturb |
| `shell/Stats.qml`, `shell/stats.py` | Machine sampling and formatting |
| `shell/Chip.qml`, `shell/Pill.qml`, `shell/ShellText.qml`, `shell/Heading.qml`, `shell/Meter.qml`, `shell/Tip.qml` | Shared UI components |

Restart after editing `stats.py`; Python is a persistent process and its source
is not watched. The QML calls `python3`, `ghostty` and `pavucontrol` by bare
name, and `default.nix` wraps the package to put exactly those three on the
unit's PATH. A new external command needs adding there as well.

To enable Quickshell's editor configuration generation:

```sh
touch modules/home/desktop/quickshell/shell/.qmlls.ini
```

That generated file is ignored by Git because its paths differ between machines.
See the upstream [editor setup](https://quickshell.org/docs/v0.2.1/guide/install-setup/)
and [Quickshell source](https://github.com/quickshell-mirror/quickshell/tree/v0.3.1).
The packaged version is 0.3.1; older examples may use incompatible Hyprland
dispatches. Workspace buttons explicitly select the Lua dispatcher when
`Hyprland.usingLua` is true.

## Limits

Counters refresh every two seconds. CPU utilization needs two samples, so the
first value is unavailable. RAM uses `MemAvailable` so reclaimable cache is not
counted as used application memory. Network rates count physical interfaces to
avoid counting the same traffic again on bridges and VPNs. Disks show `/`, home
and `/games` when present; paths on the same filesystem report the same capacity.

GPU counters depend on the driver. AMD's sysfs interface exposes utilization and
VRAM; missing counters are labelled unavailable. Temperatures come from readable
hwmon sensors. No privileged commands or external monitoring service are needed.
Tungsten already enables UPower; Uranium does not need a laptop battery widget.

Normal notifications leave the toast after their requested timeout, or seven
seconds by default, and stay actionable in the inbox until dismissed. Critical
notifications and notifications requesting no timeout stay visible. Transient
notifications expire instead of entering history. Bodies render as plain text;
inline replies, images and rich markup are not implemented. Do-not-disturb hides
toasts, including critical ones, while continuing to collect the inbox. Inbox and
do-not-disturb state are not saved to disk.

## Checks

```sh
nix build .#checks.x86_64-linux.quickshell-stats
just check
```

The first runs the counter regressions in `test_stats.py`, which `nix flake
check` also runs. Wrong counter math renders as a plausible number rather than
failing, so the arithmetic is tested and the rendering is not.

After a rebuild, confirm on the machine: launch and search, switch a workspace
by click, use a tray menu, change volume, toggle the cup, and send
`notify-send 'Quickshell test' 'Hello from the new shell'`. Check the inbox and
press Escape. A shell that fails to start leaves the session with no bar and no
notifications, so the fallback is `nixos-rebuild switch --rollback` or booting
the previous generation.
