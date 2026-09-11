pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: visualizer
    property bool playing: false
    readonly property var streams: Pipewire.nodes.values.filter(node => node.isStream && node.audio)
    readonly property var spotifyNode: streams.find(node =>
        [node.name, node.properties["application.name"], node.properties["application.process.binary"]]
            .some(value => /spotify/i.test(value ?? ""))) ?? null
    readonly property bool available: spotifyNode !== null
    property var samples: Array(48).fill(0)
    implicitHeight: 88

    // Stream metadata is populated while tracked. Monitor Spotify's stream,
    // so microphone input and unrelated application audio never drive the bars.
    PwObjectTracker { objects: visualizer.streams }
    PwNodePeakMonitor {
        id: monitor
        node: visualizer.spotifyNode
        enabled: visualizer.visible && visualizer.playing && visualizer.available
    }
    onSpotifyNodeChanged: samples = Array(48).fill(0)
    onPlayingChanged: { if (!playing) samples = Array(48).fill(0); }
    Timer {
        interval: 40; repeat: true
        running: monitor.enabled
        onTriggered: visualizer.samples = visualizer.samples.slice(1).concat([Math.max(0, Math.min(1, monitor.peak))])
    }
    Row {
        anchors.fill: parent
        spacing: 4
        Repeater {
            model: 48
            Rectangle {
                required property int index
                width: Math.max(1, (visualizer.width - 47 * 4) / 48)
                height: Math.max(3, Math.sqrt(visualizer.samples[index]) * visualizer.height)
                anchors.verticalCenter: parent.verticalCenter
                radius: width / 2
                color: index % 3 === 0 ? Theme.green : index % 3 === 1 ? Theme.mauve : Theme.pink
                opacity: visualizer.playing && visualizer.available ? 0.9 : 0.25
                Behavior on height { NumberAnimation { duration: 70 } }
            }
        }
    }
}
