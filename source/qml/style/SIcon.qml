import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15

import gui 1.0

Item {
    id: root
    property var icon
    property var iconColor: COMMON.bg6
    property var inset: 10
    property var tooltip: ""
    property var smooth: true
    property alias mouse: mouse
    property alias img: img
    height: 35
    width: 35

    MouseArea {
        anchors.fill: parent
        id: mouse
        hoverEnabled: true
    }

    SToolTip {
        id: infoToolTip
        visible: tooltip != "" && mouse.containsMouse
        delay: 100
        text: tooltip
    }

    Image {
        id: img
        source: icon
        width: parent.height - inset
        height: width
        sourceSize: Qt.size(parent.width, parent.height)
        anchors.centerIn: parent
        smooth: parent.smooth
        antialiasing: parent.smooth
        visible: !COMMON.light
    }

    ColorOverlay {
        visible: iconColor != null
        id: color
        anchors.fill: img
        source: img
        color: iconColor ? iconColor : "black"
    }
}