import QtQuick 2.15
import QtQuick.Controls 2.15

import gui 1.0

import "../style"

Rectangle {
    id: root

    property alias text: textArea.text
    property alias font: textArea.font
    property alias pointSize: textArea.pointSize
    property alias monospace: textArea.monospace
    property alias readOnly: textArea.readOnly
    property alias area: textArea
    property alias control: control
    property alias scrollBar: controlScrollBar

    property alias spelling: spelling
    property alias stream: stream
    property var tab
    property var inactive
    property var working

    property var lock: false
    property var moving: false

    function getPositionRectangle(position) {
        var rect = textArea.positionToRectangle(position)
        return root.mapFromItem(textArea, rect)
    }

    function getPositionRectangleInternal(position) {
        var rect = textArea.positionToRectangle(position)
        return rect
    }

    function ensureVisible(position) {
        if(lock || moving) {
            return;
        }
        var pos = getPositionRectangle(position)
        var delta = 0
        var diff = 9
        if(pos.y-diff < 0) {
            delta = pos.y-diff
        } else if(pos.y+pos.height+diff > root.height) {
            delta = (pos.y+pos.height+diff)-root.height
        }
        if(delta != 0) {
            control.contentY += delta
        }
    }

    function layout() {
        return
    }
    
    function overlay() {
        stream.layout()
        spelling.layout()
    }

    function clean(text) {
        return text
    }

    onActiveFocusChanged: {
        if(root.activeFocus) {
            textArea.forceActiveFocus()
        }
    }

    color: "transparent"

    SContextMenu {
        id: contextMenu
        width: 80
        SContextMenuItem {
            text: "Cut"
            onPressed: {
                textArea.cut()
            }
        }
        SContextMenuItem {
            text: "Copy"
            onPressed: {
                textArea.copy()
            }
        }
        SContextMenuItem {
            text: "Paste"
            onPressed: {
                textArea.paste()
            }
        }
    }

    Flickable {
        id: control
        anchors.fill: parent
        anchors.topMargin: -1
        anchors.bottomMargin: -1
        contentHeight: textArea.height
        contentWidth: width
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        interactive: false

        ScrollBar.vertical: SScrollBarV {
            id: controlScrollBar
            parent: control
            anchors.right: control.right
            anchors.rightMargin: -1
            barWidth: 5
            color: COMMON.bg2_5
            hoverColor: COMMON.bg4
            pressedColor: COMMON.bg5
            policy: control.height >= control.contentHeight ? ScrollBar.AlwaysOff : ScrollBar.AlwaysOn
            property var line: 1/Math.ceil((textArea.contentHeight+textArea.bottomPadding)/(textArea.font.pixelSize*2))
            stepSize: line
        }

        onContentHeightChanged: {
            root.layout()
        }

        onContentWidthChanged: {
            root.overlay()
            root.layout()
        }

        onContentYChanged: {
            root.layout()
        }

        onContentXChanged: {
            root.layout()
        }

        Rectangle {
            id: bottomLine
            x: 1
            width: parent.width-2
            height: 1
            anchors.bottom: textArea.bottom
            anchors.bottomMargin: textArea.bottomPadding - 11
            color: COMMON.bg4
        }

        Rectangle {
            id: bottomArea
            anchors.topMargin: 1
            anchors.top: bottomLine.top
            anchors.left: bottomLine.left
            anchors.right: bottomLine.right
            anchors.bottom: textArea.bottom
            color: COMMON.bg0_5
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: lineScroll.right
            anchors.right: parent.right
            anchors.rightMargin: 1
            color: COMMON.bg0_5
            visible: lineScroll.visible
        }

        Rectangle {
            id: lineScroll
            width: 1
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: 6
            visible: control.height < control.contentHeight
            color: COMMON.bg4
        }

        StreamOverlay {
            anchors.fill: textArea
            id: stream
            tab: root.tab
            textArea: root
            inactive: root.inactive
            working: root.working
        }

        TextArea {
            id: textArea
            width: parent.width
            height: Math.max(contentHeight+topPadding+bottomPadding-1, control.height)
            topPadding: 11
            leftPadding: 5
            rightPadding: 10
            bottomPadding: control.height-(textArea.font.pixelSize+17)
            wrapMode: TextArea.Wrap
            selectByMouse: true
            persistentSelection: true
            selectionColor: COMMON.selectionColor
            selectedTextColor: COMMON.selectionTextColor

            FontLoader {
                source: "qrc:/fonts/Cantarell-Regular.ttf"
            }
            FontLoader {
                source: "qrc:/fonts/SourceCodePro-Regular.ttf"
            }

            property var pointSize: 10.8
            property var monospace: false

            font.family: monospace ? "Source Code Pro" : "Cantarell"
            font.pointSize: pointSize * COORDINATOR.scale
            color: COMMON.fg1

            onCursorRectangleChanged: {
                root.ensureVisible(cursorPosition)
            }

            Keys.onPressed: {
                if(event.modifiers & Qt.ControlModifier) {
                    switch(event.key) {
                    case Qt.Key_C:
                        var text = root.clean(textArea.selectedText)
                        if(text != textArea.selectedText) {
                            GUI.copyText(text)
                            event.accepted = true
                        }
                        break;
                    }
                }

                switch(event.key) {
                case Qt.Key_Delete:
                    var c = textArea.text[textArea.cursorPosition]
                    if(c == '\u00AD') {
                        textArea.cursorPosition += 1
                    }
                    break;
                case Qt.Key_Backspace:
                    var c = textArea.text[textArea.cursorPosition-1]
                    if(c == '\u00AD') {
                        textArea.cursorPosition -= 1
                    }
                    break;
                case Qt.Key_Right:
                    var c = textArea.text[textArea.cursorPosition]
                    if(c == '\u00AD') {
                        textArea.cursorPosition += 1
                    }
                    break;
                case Qt.Key_Left:
                    var c = textArea.text[textArea.cursorPosition-1]
                    if(c == '\u00AD') {
                        textArea.cursorPosition -= 1
                    }
                    break;
                }
            }
        }

        MouseArea {
            anchors.fill: bottomArea
            onPressed: {
                return
            }
        }

        MouseArea {
            anchors.fill: textArea
            acceptedButtons: Qt.RightButton
            onPressed: {
                if(mouse.buttons & Qt.RightButton) {
                    contextMenu.popup()
                }
            }
            property var bar: controlScrollBar
            onWheel: {
                var d = wheel.angleDelta.y
                var p = Math.abs(d)/120
                if(p == 0) {
                    return
                }
                bar.stepSize = bar.line * p
                if(d < 0) {
                    bar.increase()
                } else {
                    bar.decrease()
                }
                bar.stepSize = bar.line
            }
        }


        SpellingOverlay {
            anchors.fill: textArea
            id: spelling
            tab: root.tab
            textArea: root

            function replace(start,end,text) {
                textArea.remove(start,end)
                textArea.insert(start,text)
            }
        }

        Keys.onPressed: {
            event.accepted = true
        }
    }
}