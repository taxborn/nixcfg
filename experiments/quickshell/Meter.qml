import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: meter
    property string label: ""
    property string detail: ""
    property real value: 0
    property color accent: Theme.mauve
    spacing: 6
    RowLayout {
        Layout.fillWidth: true
        ShellText { text: meter.label; Layout.fillWidth: true }
        ShellText { text: meter.detail; color: meter.accent }
    }
    Rectangle {
        Layout.fillWidth: true; implicitHeight: 6
        radius: 3; color: Theme.surface
        Rectangle {
            width: parent.width * Math.max(0, Math.min(100, meter.value)) / 100
            height: parent.height; radius: 3; color: meter.accent
            Behavior on width { NumberAnimation { duration: 300 } }
        }
    }
}
