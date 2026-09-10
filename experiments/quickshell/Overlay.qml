import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window
    screen: ShellState.popupScreen ?? ShellState.focusedScreen
    visible: ShellState.popup !== ""
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "#66000000"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-playground-overlay"
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: window.visible
        onActivated: ShellState.popup = ""
    }
    MouseArea { anchors.fill: parent; onClicked: ShellState.popup = "" }
    Rectangle {
        id: panel
        anchors.centerIn: parent
        width: Math.min(640, window.width - 40)
        height: Math.min(700, window.height - 100)
        radius: 26; color: Theme.mantle
        border { width: 2; color: Theme.mauve }
        // Consume clicks in empty card space so only the scrim closes it.
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 22; spacing: 18
            RowLayout {
                Layout.fillWidth: true
                Chip { text: "Apps"; selected: ShellState.popup === "launcher"; onClicked: ShellState.popup = "launcher" }
                Chip { text: "Machine"; selected: ShellState.popup === "dashboard"; accent: Theme.blue; onClicked: ShellState.popup = "dashboard" }
                Chip { text: "Inbox"; selected: ShellState.popup === "notifications"; accent: Theme.pink; onClicked: ShellState.popup = "notifications" }
                Item { Layout.fillWidth: true }
                Chip { text: "×"; onClicked: ShellState.popup = "" }
            }
            Loader {
                Layout.fillWidth: true; Layout.fillHeight: true
                active: window.visible
                sourceComponent: ShellState.popup === "launcher" ? launcher : ShellState.popup === "dashboard" ? dashboard : inbox
                focus: true
                onLoaded: {
                    if (ShellState.popup !== "launcher") forceActiveFocus();
                }
                Keys.onEscapePressed: ShellState.popup = ""
            }
        }
    }
    Component { id: launcher; Launcher {} }
    Component { id: dashboard; Dashboard {} }
    Component { id: inbox; Inbox {} }
}
