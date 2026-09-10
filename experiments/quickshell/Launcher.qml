pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: launcher
    spacing: 12
    readonly property var matches: {
        const terms = search.text.toLowerCase().trim().split(/\s+/);
        return DesktopEntries.applications.values.filter(app => {
            const haystack = (app.name + " " + app.genericName + " " + app.comment + " " + app.keywords.join(" ")).toLowerCase();
            return terms.every(term => haystack.includes(term));
        }).sort((a, b) => a.name.localeCompare(b.name));
    }
    function launch(index) {
        const app = matches[index];
        if (!app) return;
        // Quickshell's execute() does not wrap Terminal=true desktop entries.
        if (app.runInTerminal) {
            Quickshell.execDetached({
                command: ["ghostty", "-e"].concat(app.command),
                workingDirectory: app.workingDirectory
            });
        } else app.execute();
        ShellState.popup = "";
    }
    ShellText { text: "Launch something ✦"; color: Theme.pink; font.pixelSize: 20 }
    TextField {
        id: search
        Layout.fillWidth: true
        placeholderText: "Search applications…"
        color: Theme.text; placeholderTextColor: Theme.muted
        font.family: Theme.font; font.pixelSize: 16
        padding: 14
        background: Rectangle { color: Theme.surface; radius: 14 }
        Component.onCompleted: forceActiveFocus()
        onTextChanged: apps.currentIndex = 0
        Keys.onDownPressed: apps.currentIndex = Math.min(apps.count - 1, apps.currentIndex + 1)
        Keys.onUpPressed: apps.currentIndex = Math.max(0, apps.currentIndex - 1)
        onAccepted: launcher.launch(apps.currentIndex)
    }
    ListView {
        id: apps
        Layout.fillWidth: true; Layout.fillHeight: true
        clip: true; spacing: 4
        model: launcher.matches
        currentIndex: 0
        ScrollBar.vertical: ScrollBar {}
        delegate: Rectangle {
            id: entry
            required property var modelData
            required property int index
            width: apps.width; height: 62; radius: 14
            color: ListView.isCurrentItem ? Theme.surface : "transparent"
            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 14
                Image {
                    Layout.preferredWidth: 32; Layout.preferredHeight: 32
                    source: Quickshell.iconPath(entry.modelData.icon, "application-x-executable")
                }
                ColumnLayout {
                    Layout.fillWidth: true; spacing: 3
                    ShellText { Layout.fillWidth: true; text: entry.modelData.name; font.pixelSize: 15 }
                    ShellText { Layout.fillWidth: true; text: entry.modelData.genericName || entry.modelData.comment; color: Theme.muted; font.pixelSize: 11 }
                }
                ShellText { text: "↗"; color: Theme.mauve }
            }
            MouseArea {
                anchors.fill: parent; hoverEnabled: true
                onEntered: apps.currentIndex = entry.index
                onClicked: launcher.launch(entry.index)
            }
        }
        ShellText { anchors.centerIn: parent; visible: apps.count === 0; text: "No applications found"; color: Theme.muted }
    }
    ShellText { text: "↑ ↓ choose    Enter launch    Esc close"; color: Theme.muted; font.pixelSize: 11 }
}
