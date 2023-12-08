import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.12

import gui 1.0

import "../style"

Item {
    id: root
    
    property var position: Qt.rect(0,0,0,0)
    property var tab
    property var textArea
    property var inactive
    property var working

    function layout() {
        if(tab.marker != -1) {
            if(textArea.area.length >= tab.marker) {
                root.position = textArea.getPositionRectangleInternal(tab.marker)
            }
        } else {
            root.position = textArea.getPositionRectangleInternal(textArea.area.text.length)
        }
    }

    RectangularGlow {
        anchors.fill: marker
        visible: marker.failed || !root.working
        glowRadius: 5
        opacity: visible ? (marker.failed ? 0.75 : 0.25) : 0
        spread: 0.1
        color: marker.color
        cornerRadius: 10

        Behavior on opacity {
            PropertyAnimation{ duration: 300 }
        }
    }

    Rectangle {
        id: marker

        property var failed: false
        property var big: root.working

        x: big ? position.x : (horizontal ? position.x+2 : position.x-1)
        y: horizontal && !big ? position.y + position.height - 5 : position.y
        width: big ? 8 : (horizontal ? 10 : 2)
        height: horizontal && !big ? 2 : position.height
        visible: height != 0
        radius: big ? 1 : 0

        property var horizontal: tab.marker == -1

        color: failed ? COMMON.accent(-0.4, 0.8) : (root.inactive && !root.working ? COMMON.fg2 : COMMON.accent(0, 0.8))
        opacity: failed ? 0.9 : (root.inactive ? 0.8 : blink)
        property var blink: 0.8

        onXChanged: {
            animation.restart()
        }
        onYChanged: {
            animation.restart()
        }

        NumberAnimation on blink {
            id: animation;
            from: 1.0
            to: 0.2
            duration: 1000
            loops: Animation.Infinite
            running: true
            onDurationChanged: {
                restart()
            }
        }

        Timer {
            id: failTimer
            interval: 500
            onTriggered: {
                marker.failed = false
            }
        }

        Connections {
            target: GUI
            function onFailed() {
                marker.failed = true
                failTimer.restart()
            }
        }
    }
}