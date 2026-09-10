pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    spacing: 12
    RowLayout {
        Layout.fillWidth: true
        ShellText { text: "Little interruptions"; font.pixelSize: 20; color: Theme.pink; Layout.fillWidth: true }
        Chip { text: "Clear"; onClicked: ShellState.dismissAll() }
    }
    Chip {
        text: ShellState.quiet ? "Do not disturb · on" : "Do not disturb · off"
        selected: ShellState.quiet
        onClicked: ShellState.quiet = !ShellState.quiet
    }
    ListView {
        id: list
        Layout.fillHeight: true; Layout.fillWidth: true
        clip: true; spacing: 10
        model: ShellState.notices.slice().reverse()
        ScrollBar.vertical: ScrollBar {}
        delegate: NoticeCard {
            required property var modelData
            width: list.width
            notification: modelData.notification
        }
        ShellText { visible: list.count === 0; anchors.centerIn: parent; text: "All quiet here ✦"; color: Theme.muted }
    }
}
