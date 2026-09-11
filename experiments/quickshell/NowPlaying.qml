import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtQuick.Shapes

ColumnLayout {
    id: music
    readonly property var player: Spotify.player
    spacing: 14
    ShellText {
        Layout.alignment: Qt.AlignHCenter
        text: music.player ? (Spotify.playing ? "Spotify · now playing" : "Spotify · taking a breather") : "Spotify is quiet"
        color: Theme.green
    }
    Item {
        id: art
        Layout.alignment: Qt.AlignHCenter
        Layout.preferredWidth: 190; Layout.preferredHeight: 190

        // A squircle is the superellipse |x/rx|^n + |y/ry|^n = 1. Qt draws no
        // such primitive, so sample the curve into a polyline. n = 4.5 keeps the
        // corners fuller than a rounded rectangle without reading as a circle.
        readonly property real cornerExponent: 4.5
        readonly property int outlineSamples: 180
        readonly property var outline: {
            const points = [];
            const rx = width / 2;
            const ry = height / 2;
            const power = 2 / cornerExponent;

            for (let step = 0; step <= outlineSamples; step++) {
                const angle = 2 * Math.PI * step / outlineSamples;
                const across = Math.cos(angle);
                const down = Math.sin(angle);
                points.push(Qt.point(rx + rx * Math.sign(across) * Math.pow(Math.abs(across), power),
                                     ry + ry * Math.sign(down) * Math.pow(Math.abs(down), power)));
            }

            return points;
        }

        // One shape is both the backdrop behind missing art and the mask over
        // it. MultiEffect reads the mask's alpha, and a Shape only becomes a
        // texture it can sample once the layer is enabled.
        Shape {
            id: squircle
            anchors.fill: parent
            layer.enabled: true
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                fillColor: Theme.surface
                strokeWidth: -1
                PathPolyline { path: art.outline }
            }
        }

        ShellText { anchors.centerIn: parent; text: "♫"; font.pixelSize: 70; color: Theme.mauve }

        Image {
            id: cover
            anchors.fill: parent
            visible: false
            source: music.player?.trackArtUrl ?? ""
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 380; sourceSize.height: 380
        }

        // Ramping the mask across its antialiased edge, rather than taking the
        // default hard step at zero alpha, is what keeps the corners smooth.
        MultiEffect {
            anchors.fill: parent
            source: cover
            maskEnabled: true
            maskSource: squircle
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1.0
            visible: cover.status === Image.Ready
        }
    }
    ColumnLayout {
        Layout.fillWidth: true; spacing: 5
        ShellText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: music.player ? music.player.trackTitle || "Unknown track" : "Play something in Spotify"
            font.pixelSize: 22; font.bold: true
            maximumLineCount: 2; wrapMode: Text.Wrap
        }
        ShellText {
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            text: music.player?.trackArtist || "Your music will show up here."
            color: Theme.pink; font.pixelSize: 15
        }
        ShellText {
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            text: music.player?.trackAlbum ?? ""; color: Theme.muted
        }
    }
    AudioVisualizer {
        id: visualizer
        Layout.fillWidth: true
        Layout.preferredHeight: 88
        playing: Spotify.playing
    }
    ShellText {
        Layout.alignment: Qt.AlignHCenter
        color: Theme.muted; font.pixelSize: Theme.captionSize
        text: !music.player ? "Waiting for Spotify" : !Spotify.playing ? "Paused" : visualizer.available ? "Live audio · Spotify" : "Waiting for local Spotify audio"
    }
    RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: 18
        Chip {
            text: "󰒮"; tip: "Previous track"; implicitWidth: 56; implicitHeight: 44
            enabled: music.player?.canGoPrevious ?? false
            onClicked: music.player.previous()
        }
        Chip {
            text: Spotify.playing ? "󰏤" : "󰐊"
            tip: Spotify.playing ? "Pause" : "Play"
            selected: true; accent: Theme.green; implicitWidth: 72; implicitHeight: 44
            enabled: music.player?.canTogglePlaying ?? false
            onClicked: music.player.togglePlaying()
        }
        Chip {
            text: "󰒭"; tip: "Next track"; implicitWidth: 56; implicitHeight: 44
            enabled: music.player?.canGoNext ?? false
            onClicked: music.player.next()
        }
    }
    Item { Layout.fillHeight: true }
}
