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

    function getPositionRectangle(position) {
        var rect = textArea.positionToRectangle(position)
        return root.mapFromItem(textArea, rect)
    }

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
        contentHeight: textArea.height
        contentWidth: width
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        interactive: false

        ScrollBar.vertical: SScrollBarV {
            id: controlScrollBar
            parent: control
            anchors.top: control.top
            anchors.right: control.right
            anchors.bottom: control.bottom
            policy: control.height >= control.contentHeight ? ScrollBar.AlwaysOff : ScrollBar.AlwaysOn
            stepSize: 1/Math.ceil(textArea.contentHeight/(textArea.font.pixelSize*2))
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

        TextArea {
            id: textArea
            width: parent.width
            height: Math.max(contentHeight+topPadding+bottomPadding, root.height)
            padding: 5
            leftPadding: 5
            rightPadding: 10
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
                var y = cursorRectangle.y
                if(y < control.contentY + 5) {
                    control.contentY = y - 5
                }
                if(y >= control.contentY + control.height - 5) {
                    control.contentY = y - control.height + cursorRectangle.height + 5
                }
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
            onWheel: {
                if(wheel.angleDelta.y < 0) {
                    scrollBar.increase()
                } else {
                    scrollBar.decrease()
                }
            }
        }

        Keys.onPressed: {
            event.accepted = true
        }
    }
}