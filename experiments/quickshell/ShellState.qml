pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Notifications

Singleton {
    id: root
    property string popup: ""
    property var popupScreen: null
    property bool inhibitIdle: false
    property bool quiet: false
    property var notices: []
    onQuietChanged: {
        if (quiet) notices = notices.map(entry => ({ notification: entry.notification, until: entry.until, popup: false }));
    }
    readonly property var toasts: notices.filter(n => n.popup).slice(-4)
    readonly property var focusedScreen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0] ?? null

    function toggle(name, screen) {
        popupScreen = screen ?? focusedScreen;
        popup = popup === name ? "" : name;
    }
    function dismissAll() {
        notices.slice().forEach(entry => entry.notification.dismiss());
    }
    NotificationServer {
        id: notifications
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true;
            // Hold the actual notification so action buttons still work in the inbox.
            // Only transient notices expire when their toast disappears.
            const ttl = n.expireTimeout < 0 ? 7000 : n.expireTimeout;
            root.notices = root.notices.filter(entry => entry.notification.id !== n.id).concat([{
                notification: n,
                popup: !root.quiet && !n.lastGeneration,
                until: n.urgency === NotificationUrgency.Critical || ttl === 0 ? 0 : Date.now() + ttl
            }]);
            n.closed.connect(() => { root.notices = root.notices.filter(entry => entry.notification !== n); });
            while (root.notices.length > 50) root.notices[0].notification.dismiss();
        }
    }
    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: {
            const now = Date.now();
            root.notices.slice().forEach(entry => {
                if (entry.until > 0 && now >= entry.until && entry.notification.transient)
                    entry.notification.expire();
            });
            if (root.notices.some(entry => entry.popup && entry.until > 0 && now >= entry.until)) {
                root.notices = root.notices.map(entry => ({
                    notification: entry.notification,
                    popup: entry.popup && (entry.until === 0 || now < entry.until),
                    until: entry.until
                }));
            }
        }
    }
    IpcHandler {
        target: "shell"
        function launcher(): void { root.toggle("launcher"); }
        function dashboard(): void { root.toggle("dashboard"); }
        function notifications(): void { root.toggle("notifications"); }
        function music(): void { root.toggle("music"); }
        function close(): void { root.popup = ""; }
    }
}
