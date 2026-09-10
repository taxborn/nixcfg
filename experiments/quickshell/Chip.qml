import QtQuick
import QtQuick.Controls

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
    scale: mouse.pressed ? 0.94 : 1
    Behavior on color { ColorAnimation { duration: 120 } }
    Behavior on scale { NumberAnimation { duration: 100 } }
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
    ToolTip.visible: mouse.containsMouse && tip !== ""
    ToolTip.delay: 500
    ToolTip.text: tip
}
