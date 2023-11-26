import QtQuick 2.15
import QtQuick.Controls 2.15

import gui 1.0

import "../style"

Item {
    id: stream
    signal layout()

    property var tab
    property var textArea
    property var inactive
    property var working

    Repeater {
        model: ArrayModel {
            id: indicators
            source: tab.last
        }
        
        Rectangle {
            id: indicator
            function layout() {
                if(value == 0 && index != 0) {
                    return
                }

                var p = modelData
                var l = textArea.area.text.length

                if(p.x > l || p.y > l) {
                    indicator.position = Qt.rect(0,0,0,0)
                    return
                }

                var start = textArea.getPositionRectangleInternal(p.x)
                var end = textArea.getPositionRectangleInternal(p.y)

                if(start.y != end.y) {
                    var end_tmp = textArea.getPositionRectangleInternal(p.y-1)
                    if(start.y != end_tmp.y) {
                        var start_tmp = textArea.getPositionRectangleInternal(p.x+1)
                        if(start_tmp.y == end_tmp.y) {
                            start = start_tmp
                        } else {
                            indicator.position = Qt.rect(0,0,0,0)
                            return
                        }
                    } else {
                        end = end_tmp
                    }
                }
                indicator.position = Qt.rect(start.x, start.y, end.x-start.x, start.height)
            }

            Connections {
                target: stream
                function onLayout() {
                    layout()
                }
            }

            Component.onCompleted: {
                layout()
            }

            property var position: Qt.rect(0,0,0,0)
            property var vertical: position.width == 0
            property var value: 1

            visible: position.height != 0

            x: position.x-1
            y: vertical ? position.y : (position.y + 7)
            width: vertical ? 10 : (position.width+2)
            height: vertical ? position.height : 10
            radius: 5
            color: COMMON.accent(0, 0.5, 0.4, value)

            Timer {
                running: true
                repeat: true
                interval: 50
                onTriggered: {
                    if(index == indicators.count-1 && stream.working) {
                        return
                    }
                    parent.value -= 0.1
                    if(parent.value <= 0) {
                        parent.value = 0
                    }
                }
            }

            Rectangle {
                visible: index == 0
                x: 0
                y: vertical ? 0 : -7
                width: 2
                height: 20
                opacity: 0.8
                color: stream.inactive && !stream.working ? COMMON.fg3 : COMMON.accent(0.0, 0.7, 0.4)
            }
        }
    }
}