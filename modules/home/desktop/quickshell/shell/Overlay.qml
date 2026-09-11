import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window
    readonly property bool shown: ShellState.popup !== ""
    // The page being shown, held through the exit slide. Reading ShellState
    // directly would blank the card to the inbox on its way off screen.
    property string page: "launcher"
    // The layer surface stays mapped until the slide out ends. Unmapping on
    // close instead would cut the animation after its first frame.
    property bool mapped: false
    // Which component each tab shows. A lookup rather than a ternary chain,
    // so adding a page is one line here and one Chip in the strip below.
    readonly property var pages: ({
        launcher: launcher,
        dashboard: dashboard,
        notifications: inbox,
        music: nowPlaying
    })
    readonly property int cardWidth: 640
    readonly property int cardHeight: 700
    // The music page is shorter; its art and controls have a natural size.
    readonly property int musicHeight: 640
    screen: ShellState.popupScreen ?? ShellState.focusedScreen
    visible: mapped
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-playground-overlay"
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    Connections {
        target: ShellState
        function onPopupChanged() {
            if (ShellState.popup === "") {
                return;
            }

            window.page = ShellState.popup;
            window.mapped = true;
        }
    }
    Shortcut {
        sequence: "Escape"
        context: Qt.ApplicationShortcut
        enabled: window.shown
        onActivated: ShellState.popup = ""
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        opacity: window.shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.settleMs } }
    }
    MouseArea { anchors.fill: parent; onClicked: ShellState.popup = "" }
    Rectangle {
        id: panel
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(window.cardWidth, window.width - 40)
        height: Math.min(window.page === "music" ? window.musicHeight : window.cardHeight, window.height - 100)
        // Drops in from above the top edge, overshoots its resting spot and
        // settles back. Closing pulls it back down before it snaps away.
        y: window.shown ? (window.height - height) / 2 : -height - 20
        scale: window.shown ? 1 : 0.94
        radius: 26; color: Theme.mantle
        border { width: 2; color: Theme.mauve }
        Behavior on y {
            NumberAnimation {
                duration: Theme.slideMs
                // Back easing overshoots by roughly a tenth of the travel, and
                // this travel is half a screen, so it keeps the gentle figure.
                easing.type: window.shown ? Easing.OutBack : Easing.InBack
                easing.overshoot: Theme.nudge
                onRunningChanged: {
                    if (!running && !window.shown) {
                        window.mapped = false;
                    }
                }
            }
        }
        Behavior on scale { NumberAnimation { duration: Theme.slideMs; easing.type: Easing.OutBack; easing.overshoot: Theme.overshoot } }
        // Consume clicks in empty card space so only the scrim closes it.
        MouseArea { anchors.fill: parent }
        ColumnLayout {
            anchors.fill: parent; anchors.margins: 22; spacing: 18
            RowLayout {
                Layout.fillWidth: true
                Chip { text: "Apps"; selected: window.page === "launcher"; onClicked: ShellState.popup = "launcher" }
                Chip { text: "Machine"; selected: window.page === "dashboard"; accent: Theme.blue; onClicked: ShellState.popup = "dashboard" }
                Chip { text: "Inbox"; selected: window.page === "notifications"; accent: Theme.pink; onClicked: ShellState.popup = "notifications" }
                Chip { text: "Music"; visible: Spotify.player !== null || window.page === "music"; selected: window.page === "music"; accent: Theme.green; onClicked: ShellState.popup = "music" }
                Item { Layout.fillWidth: true }
                Chip { text: "×"; onClicked: ShellState.popup = "" }
            }
            Loader {
                Layout.fillWidth: true; Layout.fillHeight: true
                active: window.mapped
                sourceComponent: window.pages[window.page]
                focus: true
                // The launcher owns its own focus; it puts the caret in the
                // search field, and stealing it back would eat the typing.
                onLoaded: {
                    if (window.page !== "launcher") {
                        forceActiveFocus();
                    }
                }
                Keys.onEscapePressed: ShellState.popup = ""
            }
        }
    }
    Component { id: launcher; Launcher {} }
    Component { id: dashboard; Dashboard {} }
    Component { id: inbox; Inbox {} }
    Component { id: nowPlaying; NowPlaying {} }
}
