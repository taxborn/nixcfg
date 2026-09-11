pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.UPower

ScrollView {
    id: dashboard
    clip: true
    contentWidth: availableWidth
    // A core tile is wide enough for "100%" and no wider, so a busy machine
    // still fits its cores in a couple of rows.
    readonly property int coreWidth: 43
    readonly property int coreHeight: 28
    readonly property real hotCelsius: 85
    ColumnLayout {
        width: dashboard.availableWidth
        spacing: 18
        ShellText { text: "✦  " + Stats.hostname; font.pixelSize: 24; color: Theme.mauve }
        ShellText {
            Layout.fillWidth: true
            text: Stats.available ? "Up " + Stats.uptimeText() + " · Linux " + Stats.kernel : "Waiting for machine counters…"
            color: Theme.muted
        }
        Meter {
            Layout.fillWidth: true; label: "CPU"; accent: Theme.blue
            value: Stats.cpu ?? 0; detail: Stats.percent(Stats.cpu)
        }
        Flow {
            Layout.fillWidth: true; spacing: 5
            Repeater {
                model: Stats.cores
                Rectangle {
                    required property var modelData
                    width: dashboard.coreWidth; height: dashboard.coreHeight; radius: 8
                    // Load tints the tile rather than filling a bar, so a
                    // thirty-core machine still reads at a glance.
                    color: Qt.rgba(0.54, 0.71, 0.98, 0.10 + (modelData ?? 0) / 140)
                    ShellText {
                        anchors.centerIn: parent
                        text: parent.modelData === null ? "—" : Math.round(parent.modelData) + "%"
                        font.pixelSize: 10
                    }
                }
            }
        }
        ShellText { text: "Load  " + Stats.load.map(n => n.toFixed(2)).join("  /  "); color: Theme.muted }
        Meter {
            Layout.fillWidth: true; label: "Memory"; accent: Theme.green
            value: Stats.memory?.percent ?? 0
            detail: Stats.bytes(Stats.memory?.used) + " / " + Stats.bytes(Stats.memory?.total)
        }
        Meter {
            Layout.fillWidth: true; label: "Swap"; accent: Theme.peach
            value: Stats.swapPercent
            detail: Stats.bytes(Stats.memory?.swapUsed) + " / " + Stats.bytes(Stats.memory?.swapTotal)
        }
        Heading { text: "Disks" }
        Repeater {
            model: Stats.disks
            Meter {
                required property var modelData
                Layout.fillWidth: true
                label: modelData.name; value: modelData.percent; accent: Theme.mauve
                detail: Stats.bytes(modelData.used) + " / " + Stats.bytes(modelData.total)
            }
        }
        Heading { text: "Network · physical interfaces" }
        Repeater {
            model: Stats.network
            ShellText {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.name + "    ↓ " + Stats.bytes(modelData.down) + "/s    ↑ " + Stats.bytes(modelData.up) + "/s"
            }
        }
        ShellText { visible: Stats.network.length === 0; text: "No physical interfaces reported"; color: Theme.muted }
        Heading { text: "Graphics" }
        Repeater {
            model: Stats.graphics
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
        Heading { text: "Temperatures" }
        Repeater {
            model: Stats.temperatures
            ShellText {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.name + "    " + modelData.value.toFixed(1) + " °C"
                color: modelData.value >= dashboard.hotCelsius ? Theme.red : Theme.text
            }
        }
        ShellText { visible: Stats.temperatures.length === 0; text: "No readable hardware sensors"; color: Theme.muted }
        ShellText {
            visible: UPower.displayDevice?.isLaptopBattery ?? false
            text: "Battery " + Math.round((UPower.displayDevice?.percentage ?? 0) * 100) + "% · " + (UPower.onBattery ? "discharging" : "external power")
            color: Theme.green
        }
    }
}
