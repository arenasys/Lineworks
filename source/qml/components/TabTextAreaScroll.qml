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
    property var barWidth: 5
    property var areaWidth: 20
    property var barHeight: 200

    contentItem: Rectangle {
        implicitWidth: control.areaWidth
        implicitHeight: parent.barHeight
        color: "transparent"

        Rectangle {
            id: indicator
            height: parent.height
            width: control.barWidth
            anchors.left: parent.left
            anchors.leftMargin: -3
            color: control.pressed ? control.pressedColor : (control.hovered ? control.hoverColor : control.color)
            opacity: control.policy === ScrollBar.AlwaysOn || (control.active && control.size < 1.0) ? 0.75 : 0
        
            Rectangle {
                height: 1
                width: parent.width
                color: COMMON.bg4
                anchors.top: parent.top
                anchors.margins: -1
            }

            Rectangle {
                height: 1
                width: parent.width
                color: COMMON.bg4
                anchors.bottom: parent.bottom
                anchors.margins: -1
            }
        }
    }
}