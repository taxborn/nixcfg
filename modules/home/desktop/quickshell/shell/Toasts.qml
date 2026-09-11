pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window
    screen: ShellState.focusedScreen
    visible: Notices.toasts.length > 0 && ShellState.popup !== "notifications"
    anchors { top: true; right: true }
    margins { top: Theme.barHeight; right: Theme.pillMargin }
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
            add: Transition {
                NumberAnimation { property: "x"; from: notices.width; duration: Theme.slideMs; easing.type: Easing.OutBack; easing.overshoot: Theme.overshoot }
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.settleMs }
            }
            move: Transition {
                NumberAnimation { properties: "x,y"; duration: Theme.settleMs; easing.type: Easing.OutBack; easing.overshoot: Theme.nudge }
            }
            Repeater {
                model: Notices.toasts
                NoticeCard {
                    required property var modelData
                    width: notices.width
                    notification: modelData.notification
                }
            }
        }
    }
}
