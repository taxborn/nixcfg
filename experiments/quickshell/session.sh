#!/usr/bin/env bash
set -euo pipefail

shell_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
if [[ ${1:-} == ipc ]]; then
    shift
    exec qs -p "$shell_dir" ipc call shell "$@"
fi
if [[ ${1:-} == --plain ]]; then
    exec qs -p "$shell_dir"
fi
if [[ $# != 0 ]]; then
    echo 'Usage: run.sh [--plain | ipc launcher | ipc dashboard | ipc notifications | ipc close]' >&2
    exit 2
fi
: "${HYPRLAND_INSTANCE_SIGNATURE:?Run this from a terminal inside Hyprland}"
: "${XDG_RUNTIME_DIR:?A graphical user session is required}"

# A second trial must not restore services out from under the first one.
exec 9>"$XDG_RUNTIME_DIR/quickshell-playground.lock"
flock -n 9 || { echo 'The Quickshell trial is already running.' >&2; exit 1; }
active_units=()
qs_pid=
binding_changed=false
cleanup() {
    trap - EXIT INT TERM HUP
    if [[ -n $qs_pid ]]; then
        kill "$qs_pid" 2>/dev/null || true
        wait "$qs_pid" 2>/dev/null || true
    fi
    if $binding_changed; then
        # Restore this repository's launcher binding without reloading the
        # whole compositor or replaying any session startup commands.
        hyprctl eval 'hl.unbind("SUPER + R"); hl.bind("SUPER + R", hl.dsp.exec_cmd("wofi --show drun"))' >/dev/null || true
    fi
    for unit in "${active_units[@]}"; do
        systemctl --user start "$unit" || true
    done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM HUP

# Check Lua support before interrupting any desktop services.
hyprctl eval 'return "quickshell trial"' >/dev/null
for unit in waybar.service mako.service; do
    if systemctl --user is-active --quiet "$unit"; then
        active_units+=("$unit")
        systemctl --user stop "$unit"
    fi
done

qs -p "$shell_dir" &
qs_pid=$!
ready=false
for _ in {1..50}; do
    if qs -p "$shell_dir" ipc call shell close >/dev/null 2>&1; then
        ready=true
        break
    fi
    kill -0 "$qs_pid" 2>/dev/null || break
    sleep 0.1
done
$ready || { echo 'Quickshell did not start; restoring the desktop.' >&2; exit 1; }

# Shell quoting and Lua quoting are separate layers. The checkout can contain
# spaces or apostrophes, and the bind must find qs outside this nix-shell PATH.
launcher_lua=$(python3 - "$(command -v qs)" "$shell_dir" <<'PY'
import json
import shlex
import sys
command = shlex.join([sys.argv[1], "-p", sys.argv[2], "ipc", "call", "shell", "launcher"])
print('hl.unbind("SUPER + R"); hl.bind("SUPER + R", hl.dsp.exec_cmd(' + json.dumps(command) + '))')
PY
)
binding_changed=true
hyprctl eval "$launcher_lua" >/dev/null
printf '%s\n' 'Quickshell trial is running. Edit the QML files to reload. Ctrl+C restores Waybar, Mako and Super+R.'
wait "$qs_pid"
