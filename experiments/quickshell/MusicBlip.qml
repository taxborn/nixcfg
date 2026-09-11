import QtQuick

Item {
    id: blip
    property var screen
    implicitWidth: 30
    implicitHeight: 32
    visible: Spotify.playing
    Rectangle {
        anchors.centerIn: parent
        width: 22; height: 22; radius: 11
        color: Theme.green
        opacity: mouse.containsMouse ? 0.3 : 0.12
    }
    Rectangle {
        id: dot
        anchors.centerIn: parent
        width: 8; height: 8; radius: 4
        color: Theme.green
        SequentialAnimation on scale {
            running: blip.visible
            loops: Animation.Infinite
            NumberAnimation { from: 0.8; to: 1.3; duration: 420; easing.type: Easing.OutBack; easing.overshoot: Theme.overshoot }
            NumberAnimation { from: 1.3; to: 0.8; duration: 980; easing.type: Easing.OutElastic; easing.amplitude: 0.6; easing.period: 0.9 }
        }
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: ShellState.toggle("music", blip.screen)
    }
    Tip {
        target: blip
        active: mouse.containsMouse
        text: (Spotify.player?.trackTitle || "Spotify") + " · Now playing"
    }
}
