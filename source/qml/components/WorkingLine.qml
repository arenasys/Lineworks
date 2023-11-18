import QtQuick 2.15

import gui 1.0

Rectangle {
    color: COMMON.accent(0.0)
    opacity: 0.5
    clip: true

    property var progress: 0.5
    property var length: 0.4
    property var interval: 10
    property var advance: 0.05

    Rectangle {
        height: 2
        width: parent.length * parent.width
        x: (parent.progress - parent.length) * parent.width
        opacity: 0.3
    }

    Rectangle {
        height: 2
        width: parent.length * parent.width
        x: ((((1-(parent.length - parent.progress))+parent.length)%2.0)-parent.length) * parent.width
        opacity: 0.3
    }

    Timer {
        interval: parent.interval
        running: parent.visible
        repeat: true
        onTriggered: {
            parent.progress = (parent.progress + parent.advance)%2
        }
    }
}