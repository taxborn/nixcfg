import QtQuick
import Quickshell

// A Qt Quick Controls ToolTip renders inside its own window, and the bar
// window is only as tall as the bar. Qt clamps the tip back inside those
// bounds, landing it on top of the button it describes and eating the click.
// This is a real popup surface, so it hangs below the bar instead.
PopupWindow {
    id: tip
    // The item being described. Its window becomes the popup's parent.
    required property Item target
    property string text: ""
    property int delay: 400
    // Call sites bind hover here rather than to visible, which the delay owns.
    property bool active: false

    anchor {
        item: tip.target
        // Stretching the anchor box past the item is the gap under it.
        rect.width: tip.target?.width ?? 0
        rect.height: (tip.target?.height ?? 0) + 8
        edges: Edges.Bottom
        gravity: Edges.Bottom
    }
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 16
    color: "transparent"
    // An empty region accepts no input, so a tip can never swallow a click.
    mask: Region {}
    visible: false
    onActiveChanged: {
        if (active) {
            hold.restart();
            return;
        }
        hold.stop();
        tip.visible = false;
    }
    Timer {
        id: hold
        interval: tip.delay
        onTriggered: tip.visible = true
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.base
        radius: 12
        border { width: 1; color: Theme.surface }
        scale: tip.visible ? 1 : 0.85
        Behavior on scale { NumberAnimation { duration: Theme.settleMs; easing.type: Easing.OutBack; easing.overshoot: Theme.overshoot } }
        ShellText {
            id: label
            anchors.centerIn: parent
            text: tip.text
            font.pixelSize: 12
        }
    }
}
