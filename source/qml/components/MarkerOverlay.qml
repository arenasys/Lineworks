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

    /*RectangularGlow {
        anchors.fill: marker
        visible: marker.failed || !root.working
        glowRadius: 3
        opacity: visible ? (marker.failed ? 0.75 : 0.25) : 0
        spread: 0.1
        color: marker.color
        cornerRadius: 10
    }*/

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

        color: {
            if(failed) {
                return COMMON.accent(-0.4, 0.8)
            } else {
                if(root.inactive && !root.working) {
                    return COMMON.fg2
                } else { 
                    return COMMON.light ? COMMON.accent(0, 1.0) : COMMON.accent(0, 0.8)
                }
            }
        }
        opacity: failed ? 0.9 : (root.inactive ? 0.8 : (blink ? (COMMON.light ? 0.7 : 0.5) : 1.0))
        property var blink: false

        onXChanged: {
            blinker.restart()
        }
        onYChanged: {
            blinker.restart()
        }

        Timer {
            id: blinker
            interval: 500
            repeat: true
            running: GUI.windowActive
            function restart() {
                parent.blink = false
            }
            onTriggered: {
                parent.blink = !parent.blink
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