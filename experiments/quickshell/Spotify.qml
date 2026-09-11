pragma Singleton
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    readonly property var players: Mpris.players.values.filter(player =>
        player.desktopEntry.toLowerCase() === "spotify"
        || player.identity.toLowerCase() === "spotify"
        || /^org\.mpris\.MediaPlayer2\.spotify(?:\.|$)/i.test(player.dbusName))
    readonly property var player: players.find(player => player.isPlaying) ?? players[0] ?? null
    readonly property bool playing: player?.isPlaying ?? false
}
