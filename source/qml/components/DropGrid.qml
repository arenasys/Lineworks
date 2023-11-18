import QtQuick 2.15
import QtQuick.Controls 2.15

import gui 1.0

Item {
    id: root
    property var vertical: false
    property var horizonal: false
    property var center: false

    property var minorWidth: 40
    property var majorWidth: width
    property var centerWidth: width-(horizonal ? 2*minorWidth : 0)

    property var minorHeight: 40
    property var majorHeight: height
    property var centerHeight: height-(vertical ? 2*minorHeight : 0)

    property var lastPosition

    property var color: COMMON.bg5
    property var hoverColor: COMMON.fg2

    opacity: 0.5
    clip: true

    signal hovered(string position)
    signal dropped(MimeData mimeData, string position)

    function doHover(position) {
        if(position == lastPosition) {
            return
        }
        lastPosition = position
        root.hovered(position)
    }

    function doDrop(mimeData, position) {
        root.dropped(mimeData, position)
    }

    AdvancedDropArea {
        visible: vertical
        width: root.majorWidth
        height: root.minorHeight
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        filters: ['application/x-lineworks-position', 'application/x-lineworks-position-area']
        property var area: "T:L:R:"

        Rectangle {
            id: top
            anchors.top: parent.top
            x: root.horizonal ? left.width : 0
            width: root.width - (root.horizonal ? left.width + right.width : 0)
            height: parent.containsDrag ? 5 : 3
            color: parent.containsDrag ? root.hoverColor : root.color
            z: parent.containsDrag ? -100 : 0
        }

        onContainsDragChanged: {
            if(containsDrag) {
                root.doHover(area)
            } else {
                root.doHover("")
            }
        }
        onDropped: {
            root.doDrop(mimeData, area)
        }
    }

    AdvancedDropArea {
        visible: vertical
        width: root.majorWidth
        height: root.minorHeight
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        filters: ['application/x-lineworks-position', 'application/x-lineworks-position-area']
        property var area: "B:L:R:"

        Rectangle {
            id: bottom
            anchors.bottom: parent.bottom
            x: horizonal ? left.width : 0
            width: root.width - (horizonal ? left.width + right.width : 0)
            height: parent.containsDrag ? 5 : 3
            color: parent.containsDrag ? root.hoverColor : root.color
        }

        onContainsDragChanged: {
            if(containsDrag) {
                root.doHover(area)
            } else {
                root.doHover("")
            }
        }
        onDropped: {
            root.doDrop(mimeData, area)
        }
    }

    AdvancedDropArea {
        visible: horizonal
        width: root.minorWidth
        height: root.majorHeight
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        filters: ['application/x-lineworks-position', 'application/x-lineworks-position-area']
        property var area: "T:B:L:"

        Rectangle {
            id: left
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            width: parent.containsDrag ? 5 : 3
            height: root.height
            color: parent.containsDrag ? root.hoverColor : root.color
        }

        onContainsDragChanged: {
            if(containsDrag) {
                root.doHover(area)
            } else {
                root.doHover("")
            }
        }
        onDropped: {
            root.doDrop(mimeData, area)
        }
    }

    AdvancedDropArea {
        visible: horizonal
        width: root.minorWidth
        height: root.majorHeight
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        filters: ['application/x-lineworks-position', 'application/x-lineworks-position-area']
        property var area: "T:B:R:"

        Rectangle {
            id: right
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
            width: parent.containsDrag ? 5 : 3
            height: root.height
            color: parent.containsDrag ? root.hoverColor : root.color
        }

        onContainsDragChanged: {
            if(containsDrag) {
                root.doHover(area)
            } else {
                root.doHover("")
            }
        }
        onDropped: {
            root.doDrop(mimeData, area)
        }
    }

    AdvancedDropArea {
        visible: center
        width: root.centerWidth
        height: root.centerHeight
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        filters: ['application/x-lineworks-position', 'application/x-lineworks-position-area']
        property var area: "T:B:L:R:"

        onContainsDragChanged: {
            if(containsDrag) {
                root.doHover(area)
            } else {
                root.doHover("")
            }
        }
        onDropped: {
            root.doDrop(mimeData, area)
        }
    }
}