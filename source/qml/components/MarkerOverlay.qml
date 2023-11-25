import QtQuick 2.15
import QtQuick.Controls 2.15

import gui 1.0

import "../style"

Rectangle {
    id: marker
    
    property var position: Qt.rect(0,0,0,0)
    property var tab
    property var textArea
    property var inactive
    property var working

    x: horizontal ? position.x+2 : position.x-1
    y: horizontal ? position.y + position.height - 5 : position.y
    width: horizontal ? 10 : 2
    height: horizontal ? 2 : position.height
    visible: height != 0

    property var horizontal: tab.marker == -1

    function layout() {
        if(tab.marker != -1) {
            if(textArea.area.length >= tab.marker) {
                marker.position = textArea.getPositionRectangle(tab.marker)
            }
        } else {
            marker.position = textArea.getPositionRectangle(textArea.area.text.length)
        }
    }

    color: marker.inactive && !marker.working ? COMMON.fg2 : COMMON.accent(0, 0.8)

    opacity: marker.inactive ? 0.8 : blink

    property var blink: 0.8

    NumberAnimation on blink {
        id: animation;
        from: 1.0
        to: 0.2
        duration: GUI.isGenerating ? 500 : 1000
        loops: Animation.Infinite
        running: true
        onDurationChanged: {
            restart()
        }
    }
}