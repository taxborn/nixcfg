pragma Singleton
import QtQuick

QtObject {
    readonly property color base: "#1e1e2e"
    readonly property color mantle: "#181825"
    readonly property color surface: "#313244"
    readonly property color overlay: "#45475a"
    readonly property color text: "#cdd6f4"
    readonly property color muted: "#a6adc8"
    readonly property color mauve: "#cba6f7"
    readonly property color pink: "#f5c2e7"
    readonly property color peach: "#fab387"
    readonly property color green: "#a6e3a1"
    readonly property color blue: "#89b4fa"
    readonly property color red: "#f38ba8"
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property int radius: 20
    readonly property int barHeight: 54

    // Motion. One vocabulary so every surface springs the same way.
    // Easing.OutBack past its 1.70158 default is what reads as "bouncy":
    // the value overshoots its target and settles back into it.
    readonly property int pressMs: 140
    readonly property int settleMs: 260
    readonly property int slideMs: 380
    readonly property real overshoot: 3.2
    readonly property real nudge: 1.8
}
