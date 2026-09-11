pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Which popup is open, on which screen, and the ways to change that.
// Notification lifecycle lives in Notices.
Singleton {
    id: root

    property string popup: ""
    property var popupScreen: null
    property bool inhibitIdle: false

    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

    // A popup opens where it was asked for, falling back to wherever the
    // keyboard is, which is what a shortcut or an IPC call means by "here".
    function toggle(name, screen) {
        popupScreen = screen ?? focusedScreen;
        popup = popup === name ? "" : name;
    }

    IpcHandler {
        target: "shell"
        function launcher(): void {
            root.toggle("launcher");
        }
        function dashboard(): void {
            root.toggle("dashboard");
        }
        function notifications(): void {
            root.toggle("notifications");
        }
        function music(): void {
            root.toggle("music");
        }
        function close(): void {
            root.popup = "";
        }
    }
}
