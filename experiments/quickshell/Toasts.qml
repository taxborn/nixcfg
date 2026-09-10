pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window
    screen: ShellState.focusedScreen
    visible: ShellState.toasts.length > 0 && ShellState.popup !== "notifications"
    anchors { top: true; right: true }
    margins { top: Theme.barHeight + 8; right: 12 }
    implicitWidth: 380
    implicitHeight: Math.min(notices.implicitHeight, (screen?.height ?? 900) - Theme.barHeight - 40)
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-playground-toasts"
    Flickable {
        anchors.fill: parent; clip: true
        contentHeight: notices.implicitHeight
        Column {
            id: notices
            width: parent.width; spacing: 10
            Repeater {
                model: ShellState.toasts
                NoticeCard {
                    required property var modelData
                    width: notices.width
                    notification: modelData.notification
                }
            }
        }
    }
}
