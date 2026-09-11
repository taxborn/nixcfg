pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower

PanelWindow {
    id: bar
    required property var modelData
    screen: modelData
    anchors { top: true; left: true; right: true }
    implicitHeight: Theme.barHeight
    color: "transparent"
    WlrLayershell.namespace: "quickshell-playground-bar"
    readonly property var monitor: Hyprland.monitorFor(screen)
    readonly property var audio: Pipewire.defaultAudioSink?.audio ?? null
    readonly property var battery: UPower.displayDevice
    readonly property bool compact: width < 1400
    mask: Region {
        item: leftPill
        Region { item: clockPill }
        Region { item: rightPill }
    }
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    IdleInhibitor { window: bar; enabled: ShellState.inhibitIdle }
    SystemClock { id: clock; precision: SystemClock.Seconds }

    Rectangle {
        id: leftPill
        x: 10; y: 8
        width: leftRow.width + 12; height: 38
        radius: Theme.radius; color: Theme.base
        border.color: Theme.surface
        Row {
            id: leftRow
            anchors.centerIn: parent
            spacing: 2
            Chip {
                text: "✦"; accent: Theme.pink
                tip: "Applications · Super+R"
                onClicked: ShellState.toggle("launcher", bar.screen)
            }
            Repeater {
                model: 10
                Chip {
                    required property int index
                    readonly property int workspaceId: index + 1
                    readonly property var workspace: Hyprland.workspaces.values.find(w => w.id === workspaceId)
                    implicitWidth: bar.compact ? 24 : 28
                    text: workspaceId === 10 ? "0" : workspaceId.toString()
                    selected: bar.monitor?.activeWorkspace?.id === workspaceId
                    accent: workspace?.urgent ? Theme.red : selected ? Theme.mauve : workspace ? Theme.text : Theme.overlay
                    tip: "Workspace " + workspaceId
                    // The pinned compositor evaluates Lua dispatch payloads.
                    onClicked: Hyprland.dispatch(Hyprland.usingLua ? "hl.dsp.focus({ workspace = " + workspaceId + " })" : "workspace " + workspaceId)
                }
            }
        }
    }
    Rectangle {
        id: clockPill
        anchors.horizontalCenter: parent.horizontalCenter
        y: 8; width: clockRow.width + 12; height: 38
        radius: Theme.radius; color: Theme.base
        border.color: Theme.surface
        // Keep the clock in the right group if the logical display is narrow.
        visible: leftPill.width + rightPill.width + width + 60 < bar.width
        Row {
            id: clockRow
            anchors.centerIn: parent
            Chip {
                text: Qt.formatDateTime(clock.date, "ddd  HH:mm")
                accent: Theme.pink
                tip: Qt.formatDateTime(clock.date, "dddd, MMMM d, yyyy")
                onClicked: ShellState.toggle("dashboard", bar.screen)
            }
            MusicBlip { screen: bar.screen }
        }
    }
    Rectangle {
        id: rightPill
        anchors.right: parent.right; anchors.rightMargin: 10
        y: 8; width: rightRow.width + 12; height: 38
        radius: Theme.radius; color: Theme.base
        border.color: Theme.surface
        Row {
            id: rightRow
            anchors.centerIn: parent
            spacing: 2
            Chip {
                visible: !clockPill.visible
                text: Qt.formatDateTime(clock.date, "HH:mm")
                accent: Theme.pink
                onClicked: ShellState.toggle("dashboard", bar.screen)
            }
            MusicBlip {
                screen: bar.screen
                visible: !clockPill.visible && Spotify.playing
            }
            Repeater {
                model: SystemTray.items
                Item {
                    id: trayIcon
                    required property var modelData
                    width: 28; height: 32
                    Image {
                        anchors.centerIn: parent; width: 18; height: 18
                        source: trayIcon.modelData.icon
                    }
                    MouseArea {
                        id: trayMouse
                        anchors.fill: parent; hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                        onClicked: event => {
                            if (event.button === Qt.RightButton || trayIcon.modelData.onlyMenu) {
                                const pos = trayIcon.mapToItem(bar.contentItem, 0, trayIcon.height);
                                trayIcon.modelData.display(bar, pos.x, pos.y);
                            } else if (event.button === Qt.MiddleButton) trayIcon.modelData.secondaryActivate();
                            else trayIcon.modelData.activate();
                        }
                        onWheel: event => trayIcon.modelData.scroll(event.angleDelta.y, false)
                    }
                    Tip {
                        target: trayIcon
                        active: trayMouse.containsMouse
                        text: trayIcon.modelData.tooltipTitle || trayIcon.modelData.title
                    }
                }
            }
            Chip {
                text: "CPU " + Stats.percent(Stats.data.cpu)
                accent: Theme.blue; tip: "Machine details"
                onClicked: ShellState.toggle("dashboard", bar.screen)
            }
            Chip {
                visible: !bar.compact
                text: "RAM " + Stats.percent(Stats.data.memory?.percent)
                accent: Theme.green; tip: "Memory, swap, disks and temperatures"
                onClicked: ShellState.toggle("dashboard", bar.screen)
            }
            Chip {
                visible: !bar.compact
                text: "↓ " + Stats.bytes((Stats.data.network ?? []).reduce((sum, n) => sum + n.down, 0)) + "/s"
                accent: Theme.blue; tip: "Network throughput and hardware sensors"
                onClicked: ShellState.toggle("dashboard", bar.screen)
            }
            Chip {
                text: ShellState.inhibitIdle ? "󰅶" : "󰾪"
                selected: ShellState.inhibitIdle; accent: Theme.peach
                tip: ShellState.inhibitIdle ? "Stay awake is on. Click to allow idle." : "Keep this session awake"
                onClicked: ShellState.inhibitIdle = !ShellState.inhibitIdle
            }
            Chip {
                text: !bar.audio ? "󰖁 —" : bar.audio.muted ? "󰖁" : "󰕾 " + Math.round(bar.audio.volume * 100)
                accent: Theme.mauve
                tip: "Click: mixer · Right click: mute · Scroll: volume"
                onClicked: Quickshell.execDetached(["pavucontrol"])
                onRightClicked: { if (bar.audio) bar.audio.muted = !bar.audio.muted; }
                onScrolled: delta => { if (bar.audio) bar.audio.volume = Math.max(0, Math.min(1, bar.audio.volume + (delta > 0 ? 0.05 : -0.05))); }
            }
            Chip {
                visible: bar.battery?.isLaptopBattery ?? false
                text: (UPower.onBattery ? "󰁹 " : "󰂄 ") + Math.round((bar.battery?.percentage ?? 0) * 100) + "%"
                accent: (bar.battery?.percentage ?? 1) < 0.2 ? Theme.red : Theme.green
                tip: "Battery and power details"
                onClicked: ShellState.toggle("dashboard", bar.screen)
            }
            Chip {
                text: (ShellState.quiet ? "󰂛 " : "󰂚 ") + ShellState.notices.length
                accent: Theme.pink
                tip: "Notifications · Right click: do not disturb"
                selected: ShellState.quiet
                onClicked: ShellState.toggle("notifications", bar.screen)
                onRightClicked: ShellState.quiet = !ShellState.quiet
            }
        }
    }
}
