import QtQuick

// One of the bar's floating groups. Children go into a Row, and the pill
// takes its width from them, so a group grows and shrinks with its contents.
Rectangle {
    default property alias content: row.data
    property alias spacing: row.spacing

    anchors.verticalCenter: parent.verticalCenter
    implicitWidth: row.width + Theme.pillPadding
    implicitHeight: Theme.pillHeight
    radius: Theme.radius
    color: Theme.base
    border.color: Theme.surface

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2
    }
}
