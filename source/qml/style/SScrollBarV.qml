import QtQuick 2.15
import QtQuick.Controls 2.15

import gui 1.0

ScrollBar {
    id: control
    size: 0.3
    position: 0.2
    active: true
    orientation: Qt.Vertical
    property var color: COMMON.bg5
    property var hoverColor: COMMON.bg5
    property var pressedColor: COMMON.bg7
    property var barWidth: 6
    property var barHeight: 200

    contentItem: Rectangle {
        implicitWidth: control.barWidth * 2
        implicitHeight: parent.barHeight
        color: "transparent"

        Rectangle {
            id: indicator
            height: parent.height
            width: control.barWidth
            anchors.right: parent.right
            color: control.pressed ? control.pressedColor : (control.hovered ? control.hoverColor : control.color)
            opacity: control.policy === ScrollBar.AlwaysOn || (control.active && control.size < 1.0) ? 0.75 : 0
        }
    }
}