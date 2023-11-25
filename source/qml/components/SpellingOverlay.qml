import QtQuick 2.15
import QtQuick.Controls 2.15

import gui 1.0

import "../style"

Item {
    id: spelling

    signal layout()

    property var tab
    property var textArea

    property var minCursor: 0
    property var maxCursor: 0

    function replace(start, end, text) {
        return
    }

    Connections {
        target: tab.spellchecker

        function onInsert(i, word) {
            words.insert(i, {"data":word})
        }

        function onRemove(i) {
            words.remove(i)
        }
    }

    Repeater {
        model: ListModel {
            id: words
        }
        
        Item {
            id: word

            property var span: modelData.span
            property var suggestions: modelData.suggestions

            function layout() {
                if(suggestions.length == 0) {
                    return
                }

                var p = modelData.span
                var l = textArea.area.text.length

                if(p.x > l || p.y > l) {
                    word.position = Qt.rect(0,0,0,0)
                    return
                }

                if(tab.marker != -1) {
                    if(p.x > tab.marker) {
                        p = Qt.point(p.x+1, p.y)
                    }
                    if(p.y > tab.marker) {
                        p = Qt.point(p.x, p.y+1)
                    }
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
                            word.position = Qt.rect(0,0,0,0)
                            return
                        }
                    } else {
                        end = end_tmp
                    }
                }
                word.position = Qt.rect(start.x, start.y, end.x-start.x, start.height)
            }

            Connections {
                target: spelling
                function onLayout() {
                    layout()
                }
            }

            Connections {
                target: modelData
                function onSuggestionsChanged() {
                    layout()
                }
            }

            Component.onCompleted: {
                layout()
            }

            property var position: Qt.rect(0,0,0,0)

            visible: position.height != 0

            property var alignedWidth: Math.ceil(position.width/interval)*interval
            property var alignedOffset: Math.ceil((position.width - alignedWidth)/2)

            x: position.x
            y: position.y + 17
            width: position.width
            height: 4

            property var interval: 4

            Item {
                anchors.fill: parent
                clip: true
                Repeater {
                    model: parent.visible ? Math.ceil(parent.width/interval) : 0
                    Rectangle {
                        visible: true
                        x: interval * index
                        y: 1
                        width: 0.707*2*interval
                        rotation: (index%2 == 0 ? 45 : 315)
                        height: 2
                        color: "#aa2222"
                        antialiasing: true
                    }
                }
            }

            MouseArea {
                z: 100
                anchors.fill: parent
                anchors.topMargin: -17
                acceptedButtons: Qt.RightButton
                onPressed: {
                    suggestionMenu.popup()
                }
            }

            SContextMenu {
                id: suggestionMenu

                Instantiator {
                    model: suggestions
                    SContextMenuItem {
                        text: modelData

                        onPressed: {
                            spelling.replace(span.x, span.y, modelData)
                        }
                    }
                    onObjectAdded: suggestionMenu.insertItem(index, object)
                    onObjectRemoved: suggestionMenu.removeItem(object)
                }

                SMenuSeparator {}

                SContextMenuItem {
                    text: "Add to dictionary"
                }
            }
        }
    }
}