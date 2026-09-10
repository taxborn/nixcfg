pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var data: ({})
    property double lastUpdate: 0
    property bool available: false
    Process {
        id: collector
        command: ["python3", "-u", Quickshell.shellPath("stats.py")]
        running: true
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.data = JSON.parse(line);
                    root.lastUpdate = Date.now();
                    root.available = true;
                } catch (error) { console.warn("Stats:", error); }
            }
        }
        onExited: { root.available = false; restart.start(); }
    }
    Timer { id: restart; interval: 5000; onTriggered: collector.running = true }
    Timer {
        interval: 3000; repeat: true; running: true
        onTriggered: root.available = Date.now() - root.lastUpdate < 8000
    }
    function percent(value) { return available && value !== undefined && value !== null ? Math.round(value) + "%" : "—"; }
    function bytes(value) {
        if (value === undefined || value === null) return "—";
        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (value >= 1024 && i < units.length - 1) { value /= 1024; ++i; }
        return value.toFixed(i > 1 ? 1 : 0) + " " + units[i];
    }
}
