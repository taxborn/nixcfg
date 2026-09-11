pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.Mpris

ScrollView {
    id: dashboard
    clip: true
    contentWidth: availableWidth
    ColumnLayout {
        width: dashboard.availableWidth
        spacing: 18
        ShellText { text: "✦  " + (Stats.data.hostname ?? "Your machine"); font.pixelSize: 24; color: Theme.mauve }
        ShellText {
            Layout.fillWidth: true
            text: Stats.available ? "Up " + Math.floor((Stats.data.uptime ?? 0) / 3600) + "h " + Math.floor((Stats.data.uptime ?? 0) % 3600 / 60) + "m · Linux " + (Stats.data.kernel ?? "") : "Waiting for machine counters…"
            color: Theme.muted
        }
        Meter {
            Layout.fillWidth: true; label: "CPU"; accent: Theme.blue
            value: Stats.data.cpu ?? 0; detail: Stats.percent(Stats.data.cpu)
        }
        Flow {
            Layout.fillWidth: true; spacing: 5
            Repeater {
                model: Stats.data.cores ?? []
                Rectangle {
                    required property var modelData
                    required property int index
                    width: 43; height: 28; radius: 8
                    color: Qt.rgba(0.54, 0.71, 0.98, 0.10 + (modelData ?? 0) / 140)
                    ShellText { anchors.centerIn: parent; text: parent.modelData === null ? "—" : Math.round(parent.modelData) + "%"; font.pixelSize: 10 }
                }
            }
        }
        ShellText { text: "Load  " + (Stats.data.load ?? []).map(n => n.toFixed(2)).join("  /  "); color: Theme.muted }
        Meter {
            Layout.fillWidth: true; label: "Memory"; accent: Theme.green
            value: Stats.data.memory?.percent ?? 0
            detail: Stats.bytes(Stats.data.memory?.used) + " / " + Stats.bytes(Stats.data.memory?.total)
        }
        Meter {
            Layout.fillWidth: true; label: "Swap"; accent: Theme.peach
            value: Stats.data.memory?.swapTotal ? 100 * Stats.data.memory.swapUsed / Stats.data.memory.swapTotal : 0
            detail: Stats.bytes(Stats.data.memory?.swapUsed) + " / " + Stats.bytes(Stats.data.memory?.swapTotal)
        }
        ShellText { text: "Disks"; color: Theme.pink; font.pixelSize: 17 }
        Repeater {
            model: Stats.data.disks ?? []
            Meter {
                required property var modelData
                Layout.fillWidth: true
                label: modelData.name; value: modelData.percent; accent: Theme.mauve
                detail: Stats.bytes(modelData.used) + " / " + Stats.bytes(modelData.total)
            }
        }
        ShellText { text: "Network · physical interfaces"; color: Theme.pink; font.pixelSize: 17 }
        Repeater {
            model: Stats.data.network ?? []
            ShellText {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.name + "    ↓ " + Stats.bytes(modelData.down) + "/s    ↑ " + Stats.bytes(modelData.up) + "/s"
            }
        }
        ShellText { visible: !(Stats.data.network?.length); text: "No physical interfaces reported"; color: Theme.muted }
        ShellText { text: "Graphics"; color: Theme.pink; font.pixelSize: 17 }
        Repeater {
            model: Stats.data.graphics ?? []
            ColumnLayout {
                id: gpu
                required property var modelData
                Layout.fillWidth: true
                ShellText {
                    Layout.fillWidth: true
                    text: gpu.modelData.name + " · " + (gpu.modelData.busy === null ? "utilization unavailable" : Stats.percent(gpu.modelData.busy))
                }
                ShellText {
                    visible: gpu.modelData.vramTotal !== null
                    text: "VRAM " + Stats.bytes(gpu.modelData.vramUsed) + " / " + Stats.bytes(gpu.modelData.vramTotal)
                    color: Theme.muted
                }
            }
        }
        ShellText { text: "Temperatures"; color: Theme.pink; font.pixelSize: 17 }
        Repeater {
            model: Stats.data.temperatures ?? []
            ShellText {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.name + "    " + modelData.value.toFixed(1) + " °C"
                color: modelData.value >= 85 ? Theme.red : Theme.text
            }
        }
        ShellText { visible: !(Stats.data.temperatures?.length); text: "No readable hardware sensors"; color: Theme.muted }
        ShellText {
            visible: UPower.displayDevice?.isLaptopBattery ?? false
            text: "Battery " + Math.round((UPower.displayDevice?.percentage ?? 0) * 100) + "% · " + (UPower.onBattery ? "discharging" : "external power")
            color: Theme.green
        }
    }
}
