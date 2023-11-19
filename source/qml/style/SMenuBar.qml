import QtQuick 2.15
import QtQuick.Controls 2.15

import gui 1.0

MenuBar {
    id: menuBar
    readonly property real menuBarHeight: 20
    readonly property real menuBarWidth: 50
    height: menuBarHeight
    contentHeight: menuBarHeight

    property var pointSize: 10.5
    property var color: COMMON.fg1

    delegate: MenuBarItem {
            id: menuBarItem
            implicitHeight: menuBarHeight
            implicitWidth: menuBarWidth
            hoverEnabled: true
            contentItem: Item {

            }

            background: Rectangle {
                SText {
                    text: menuBarItem.text
                    opacity: enabled ? 1.0 : 0.3
                    color: menuBarItem.hovered && !menuBar.parent.activeFocus ? COMMON.fg1 : COMMON.fg1_5
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                    anchors.fill: parent
                    pointSize: menuBar.pointSize
                }

                implicitWidth: menuBarWidth
                implicitHeight: menuBarHeight
                opacity: enabled ? 1 : 0.3
                color: menuBarItem.hovered && !menuBar.parent.activeFocus ?  COMMON.bg3_5 : "transparent"
            }
    }

    background: Rectangle {
        implicitHeight: menuBarHeight
        color: COMMON.bg2_5

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: COMMON.light ? COMMON.bg4 : COMMON.bg4
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: -1
            height: 1
            color: COMMON.light ? COMMON.bg4 : COMMON.bg4
        }
    }
}