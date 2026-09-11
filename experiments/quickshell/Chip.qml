import QtQuick

Rectangle {
    id: root
    property string text: ""
    property string tip: ""
    property color accent: Theme.mauve
    property bool selected: false
    signal clicked()
    signal rightClicked()
    signal scrolled(real delta)
    implicitWidth: label.implicitWidth + 20
    implicitHeight: 32
    radius: 12
    color: selected ? accent : mouse.containsMouse ? Theme.overlay : "transparent"
    scale: mouse.pressed ? 0.88 : mouse.containsMouse ? 1.06 : 1
    Behavior on color { ColorAnimation { duration: Theme.pressMs } }
    Behavior on scale { NumberAnimation { duration: Theme.pressMs; easing.type: Easing.OutBack; easing.overshoot: Theme.overshoot } }
    ShellText {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: root.selected ? Theme.base : root.accent
    }
    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: event => event.button === Qt.RightButton ? root.rightClicked() : root.clicked()
        onWheel: event => root.scrolled(event.angleDelta.y)
    }
    Tip {
        target: root
        active: mouse.containsMouse && root.tip !== ""
        delay: 500
        text: root.tip
    }
}
