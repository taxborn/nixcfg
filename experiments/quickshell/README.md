# Quickshell playground

An editable shell for Tungsten and Uranium. Catppuccin Mocha, floating panels,
rounded buttons and a few pastel accents. It runs on the existing Hyprland
configuration and keeps its shortcuts, monitor layouts, window rules, wallpaper,
clipboard picker, lock screen and idle handling.

## Try it

From a terminal inside Hyprland, at the root of this checkout:

```sh
./experiments/quickshell/run.sh
```

The first run fetches Quickshell and Python from this repository's pinned
nixpkgs. Both workstations use the same packages and architecture, so the script
uses Uranium's package set on either machine. It does not rebuild or deploy NixOS.

The trial stops the active `waybar.service` and `mako.service`, starts Quickshell,
and temporarily routes **Super+R** to its launcher. All other bindings stay as
they are, including the clipboard picker, which still uses Wofi. NetworkManager
and Bluetooth applets keep running and register with the new tray.

Keep the terminal open. **Ctrl+C** stops the trial, restores Super+R to Wofi and
restarts only the services that were active before it began. Startup failures
also restore them. The launcher binding assumes this checkout's existing
`wofi --show drun` command. Reloading Hyprland during the trial restores that
binding early; the star button still opens the Quickshell launcher.

If the terminal or script is forcibly killed before cleanup runs, recover with:

```sh
qs -p "$PWD/experiments/quickshell" kill
hyprctl eval 'hl.unbind("SUPER + R"); hl.bind("SUPER + R", hl.dsp.exec_cmd("wofi --show drun"))'
systemctl --user start waybar.service mako.service
```

Run the first command inside the same `nix shell` environment if `qs` is not on
your normal PATH. Alternatively, use the pinned executable with
`nix shell .#nixosConfigurations.uranium.pkgs.quickshell --command qs -p "$PWD/experiments/quickshell" kill`.

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

## Edit it

Edit these files in the checkout while the trial is running. Quickshell watches
QML changes and reloads them without a Nix rebuild.

| File | Change here |
| --- | --- |
| `Theme.qml` | Colours, font, corner radius, bar height and motion timings |
| `Overlay.qml` | Popup card, its slide in from the top edge and the tab strip |
| `Bar.qml` | Bar contents, spacing and responsive layout |
| `Launcher.qml` | Search, application rows and terminal choice |
| `Dashboard.qml` | Machine details |
| `Spotify.qml`, `MusicBlip.qml`, `NowPlaying.qml` | Spotify detection, clock blip and player panel |
| `AudioVisualizer.qml` | Live Spotify amplitude history |
| `NoticeCard.qml`, `Inbox.qml`, `Toasts.qml` | Notification appearance |
| `ShellState.qml` | Which popup is open, on which screen, and IPC |
| `Notices.qml` | Notification lifecycle, toast expiry and do-not-disturb |
| `Stats.qml`, `stats.py` | Machine sampling and formatting |
| `Chip.qml`, `Pill.qml`, `ShellText.qml`, `Heading.qml`, `Meter.qml`, `Tip.qml` | Shared UI components |

Restart the trial after editing `stats.py`; Python is a persistent process and
its source is not watched. To enable Quickshell's editor configuration generation:

```sh
touch experiments/quickshell/.qmlls.ini
```

That generated file is ignored by Git because its paths differ between machines.
See the upstream [editor setup](https://quickshell.org/docs/v0.2.1/guide/install-setup/)
and [Quickshell source](https://github.com/quickshell-mirror/quickshell/tree/v0.3.1).
The local package is 0.3.1; older examples may use incompatible Hyprland dispatches.
Workspace buttons explicitly select the Lua dispatcher when `Hyprland.usingLua`
is true.

You can also control the running shell from a second terminal:

```sh
./experiments/quickshell/run.sh ipc launcher
./experiments/quickshell/run.sh ipc dashboard
./experiments/quickshell/run.sh ipc notifications
./experiments/quickshell/run.sh ipc music
./experiments/quickshell/run.sh ipc close
```

`run.sh --plain` starts only Quickshell, without managing services or bindings.
Use that only when you have already stopped the other notification server and bar.

The Spotify component uses the desktop app's local MPRIS interface, with no
account connection or API credentials. Its visualizer shows about two seconds of
amplitude history from Spotify's PipeWire stream. It does not sample microphones
or the full desktop mix. Sampling stops when the panel closes or playback pauses.
If Spotify is playing remotely through Connect, the metadata and controls may
still work, but there is no local audio to visualize. The panel shows that state.
The blip follows the clock into the right section on narrow displays.

## Limits of this first version

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

The Hyprland configuration is deliberately still the existing one. Once the shell
feels right, the next step is a Home Manager module with a session-bound service,
Quickshell as the launcher target, and Waybar/Mako disabled declaratively.

## Checks

```sh
python3 -m unittest discover -s experiments/quickshell -p 'test_*.py'
just check
```

The tests cover counter math and trial cleanup after normal exit, startup failure,
binding failure and initially inactive services. The cleanup tests substitute
fake desktop commands and never touch a running session.

For a live check on each machine: launch and search, switch a workspace by click,
use a tray menu, change volume, toggle the cup, and send
`notify-send 'Quickshell test' 'Hello from the new shell'`. Check the inbox, press
Escape, then Ctrl+C in the trial terminal and confirm the previous bar and
notifications return. No deployment is needed for this trial.
