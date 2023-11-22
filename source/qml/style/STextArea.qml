import QtQuick 2.15
import QtQuick.Controls 2.15

import gui 1.0

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

    function layout() {
        return
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
            color: COMMON.bg3
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
            root.layout()
        }

        onContentYChanged: {
            root.layout()
        }

        onContentXChanged: {
            root.layout()
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

        TextArea {
            id: textArea
            width: parent.width
            height: Math.max(contentHeight+topPadding+bottomPadding, control.height)
            topPadding: 5
            leftPadding: 5
            rightPadding: 10
            bottomPadding: 5
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

        Keys.onPressed: {
            event.accepted = true
        }
    }
}