import QtQuick 2.15
import QtQuick.Controls 2.15

import gui 1.0

import "../style"

Item {
    id: spelling
    visible: GUI.spellOverlay

    signal layout()

    property var tab
    property var textArea

    property var minY
    property var maxY

    function replace(start, end, text) {
        return
    }

    Timer {
        id: checkTimer
        interval: 500
        onTriggered: {
            if(tab.spellchecker.check()) {
                restart()
            }
        }
    }

    onVisibleChanged: {
        update()
    }

    function update() {
        if(visible) {
            tab.spellchecker.update(textArea.area.text)
            checkTimer.restart()
        }
    }

    Repeater {
        model: ArrayModel {
            source: tab.spellchecker.lines
        }
        Item {
            id: line

            property var start: 0
            property var end: 0
            property var span: model.data.span
            property var showing: (start > minY && start < maxY) || (end > minY && end < maxY)
            property var changed: false

            signal layout()

            function check() {
                var s = textArea.getPositionRectangleInternal(span.x).y
                var e = textArea.getPositionRectangleInternal(span.y).y
                var redo = s != start

                start = s
                end = e

                if(redo) {
                    changed = true
                }

                if(showing && changed) {
                    changed = false
                    line.layout()
                }
            }

            Connections {
                target: spelling
                function onLayout() {
                    check()
                }
                function onMaxYChanged() {
                    check()
                }
            }

            Connections {
                target: model.data
                function onSpanChanged() {
                    check()
                }
            }

            Component.onCompleted: {
                start = textArea.getPositionRectangleInternal(span.x).y
                end = textArea.getPositionRectangleInternal(span.y).y
            }

            Repeater {

                model: ArrayModel {
                    id: incorrect
                    source: model.data.incorrect
                }

                Item {
                    id: word

                    property var span: model.data.span

                    property var initial: true

                    Timer {
                        id: delayTimer
                        onTriggered: {
                            layout()
                        }
                    }

                    function getSpan() {
                        var p = Qt.point(line.span.x + span.x, line.span.x + span.y)
                        if(tab.marker != -1) {
                            if(p.x > tab.marker) {
                                p = Qt.point(p.x+1, p.y)
                            }
                            if(p.y > tab.marker) {
                                p = Qt.point(p.x, p.y+1)
                            }
                        }
                        return p
                    }

                    function layout() {
                        if(!line.showing) {
                            return
                        }

                        if(initial) {
                            initial = false
                            delayTimer.interval = Math.floor(100 * Math.random())
                            delayTimer.start()
                            return
                        }

                        var p = getSpan()
                        var l = textArea.area.text.length

                        if(p.x > l || p.y > l) {
                            word.position = Qt.rect(0,0,0,0)
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
                        target: model.data
                        function onSpanChanged() {
                            layout()
                        }
                    }

                    Connections {
                        target: line
                        function onLayout() {
                            layout()
                        }
                        function onShowingChanged() {
                            if(line.showing) {
                                layout()
                            }
                        }
                    }

                    Component.onCompleted: {
                        layout()
                    }

                    property var position: Qt.rect(0,0,0,0)

                    visible: position.height != 0 && line.showing

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
                            suggestionMenu.model = tab.spellchecker.getSuggestions(model.data.word)
                            suggestionMenu.span = word.getSpan()
                            suggestionMenu.word = model.data.word
                            suggestionMenu.popup()
                        }
                    }
                }
            }
        }
    }

    SContextMenu {
        id: suggestionMenu
        property var word: ""
        property var span: Qt.point(0,0)
        property var model: []

        Instantiator {
            model: suggestionMenu.model
            SContextMenuItem {
                text: modelData

                onPressed: {
                    spelling.replace(suggestionMenu.span.x, suggestionMenu.span.y, modelData)
                }
            }
            onObjectAdded: suggestionMenu.insertItem(index, object)
            onObjectRemoved: suggestionMenu.removeItem(object)
        }

        SMenuSeparator {}

        SContextMenuItem {
            text: "Add to dictionary"

            onPressed: {
                if(tab.spellchecker.addWord(suggestionMenu.word)) {
                    checkTimer.restart()
                }
            }
        }
    }
}