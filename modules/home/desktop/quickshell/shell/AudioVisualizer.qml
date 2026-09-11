pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.Pipewire

Item {
    id: visualizer
    property bool playing: false

    // The bars are a scrolling history, not a spectrum: one sample per frame
    // shifted in from the right. At this interval they hold about two seconds.
    readonly property int barCount: 48
    readonly property int barSpacing: 4
    readonly property int sampleMs: 40

    readonly property var streams: Pipewire.nodes.values.filter(node => node.isStream && node.audio)
    readonly property var spotifyNode: streams.find(node =>
        [node.name, node.properties["application.name"], node.properties["application.process.binary"]]
            .some(value => /spotify/i.test(value ?? ""))) ?? null
    readonly property bool available: spotifyNode !== null

    property var samples: blank()
    implicitHeight: 88

    function blank() {
        return Array(barCount).fill(0);
    }

    // Stream metadata is populated while tracked. Monitor Spotify's stream,
    // so microphone input and unrelated application audio never drive the bars.
    PwObjectTracker { objects: visualizer.streams }
    PwNodePeakMonitor {
        id: monitor
        node: visualizer.spotifyNode
        enabled: visualizer.visible && visualizer.playing && visualizer.available
    }
    onSpotifyNodeChanged: samples = blank()
    onPlayingChanged: {
        if (!playing) {
            samples = blank();
        }
    }
    Timer {
        interval: visualizer.sampleMs
        repeat: true
        running: monitor.enabled
        onTriggered: visualizer.samples = visualizer.samples.slice(1).concat([Math.max(0, Math.min(1, monitor.peak))])
    }
    Row {
        anchors.fill: parent
        spacing: visualizer.barSpacing
        Repeater {
            model: visualizer.barCount
            Rectangle {
                required property int index
                width: Math.max(1, (visualizer.width - (visualizer.barCount - 1) * visualizer.barSpacing) / visualizer.barCount)
                // Square root, because peak amplitude is linear and hearing is
                // not; a quiet passage would otherwise barely leave the floor.
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
