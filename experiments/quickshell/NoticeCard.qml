pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Notifications

Rectangle {
    id: card
    required property var notification
    implicitHeight: contents.implicitHeight + 28
    radius: Theme.radius
    color: Theme.base
    border.color: notification.urgency === NotificationUrgency.Critical ? Theme.red : Theme.overlay
    ColumnLayout {
        id: contents
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
        spacing: 8
        RowLayout {
            ShellText { Layout.fillWidth: true; text: card.notification.appName || "Notification"; color: Theme.mauve; font.pixelSize: 11 }
            Chip { text: "×"; implicitHeight: 24; tip: "Dismiss"; onClicked: card.notification.dismiss() }
        }
        ShellText { Layout.fillWidth: true; text: card.notification.summary; font.pixelSize: 15; font.bold: true; wrapMode: Text.Wrap; maximumLineCount: 3 }
        ShellText { Layout.fillWidth: true; text: card.notification.body; visible: text !== ""; color: Theme.muted; wrapMode: Text.Wrap; maximumLineCount: 8 }
        Flow {
            Layout.fillWidth: true; spacing: 6
            Repeater {
                model: card.notification.actions
                Chip {
                    required property var modelData
                    text: modelData.text || "Open"; accent: Theme.green
                    onClicked: modelData.invoke()
                }
            }
        }
    }
}
