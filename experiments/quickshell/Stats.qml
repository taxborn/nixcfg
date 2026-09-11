pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // A packet lands every two seconds, so three missed ones mean the
    // collector is wedged or gone, not merely slow.
    readonly property int staleMs: 8000
    readonly property int checkMs: 3000
    readonly property int restartMs: 5000

    property var data: ({})
    property double lastUpdate: 0
    property bool available: false

    // Defaulted views over the last packet. Without these every call site
    // repeats the same guard for the window before the first sample lands.
    // cpu stays null there, so the bar reads "—" rather than a false zero.
    readonly property var cpu: data.cpu ?? null
    readonly property var memory: data.memory ?? null
    readonly property var cores: data.cores ?? []
    readonly property var disks: data.disks ?? []
    readonly property var graphics: data.graphics ?? []
    readonly property var network: data.network ?? []
    readonly property var temperatures: data.temperatures ?? []
    readonly property var load: data.load ?? []
    readonly property string hostname: data.hostname ?? "Your machine"
    readonly property string kernel: data.kernel ?? ""
    readonly property real uptime: data.uptime ?? 0

    readonly property real swapPercent: memory?.swapTotal ? 100 * memory.swapUsed / memory.swapTotal : 0
    // The bar has room for one number, not one per interface.
    readonly property real totalDown: network.reduce((sum, link) => sum + link.down, 0)

    function percent(value) {
        return available && value !== undefined && value !== null ? Math.round(value) + "%" : "—";
    }

    function bytes(value) {
        if (value === undefined || value === null) {
            return "—";
        }

        const units = ["B", "KiB", "MiB", "GiB", "TiB"];
        let i = 0;
        while (value >= 1024 && i < units.length - 1) {
            value /= 1024;
            ++i;
        }

        return value.toFixed(i > 1 ? 1 : 0) + " " + units[i];
    }

    function uptimeText() {
        return Math.floor(uptime / 3600) + "h " + Math.floor(uptime % 3600 / 60) + "m";
    }

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
                } catch (error) {
                    console.warn("Stats:", error);
                }
            }
        }
        onExited: {
            root.available = false;
            restart.start();
        }
    }

    Timer {
        id: restart
        interval: root.restartMs
        onTriggered: collector.running = true
    }

    Timer {
        interval: root.checkMs
        repeat: true
        running: true
        onTriggered: root.available = Date.now() - root.lastUpdate < root.staleMs
    }
}
