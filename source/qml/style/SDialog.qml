import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.15

import gui 1.0

Dialog {
    id: dialog
    anchors.centerIn: parent
    width: 300
    dim: true

    onOpened: {
        buttonBox.forceActiveFocus()
    }

    padding: 5

    background: Item {
        RectangularGlow {
            anchors.fill: bg
            glowRadius: 5
            opacity: 0.75
            spread: 0.2
            color: "black"
            cornerRadius: 10
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            anchors.margins: -1
            color: COMMON.bg2
            border.width: 1
            border.color: COMMON.bg4
        }
        Rectangle {
            anchors.fill: parent
            anchors.margins: -2
            color: "transparent"
            border.width: 1
            border.color: COMMON.bg0
        }
    }

    header: Item {
        implicitHeight: 20
        SText {
            color: COMMON.fg2
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: dialog.title
            pointSize: 9
        }
    }

    contentItem: Rectangle {
        color: COMMON.bg3
        border.width: 1
        border.color: COMMON.bg4
    }

    spacing: 0
    verticalPadding: 0

    footer: Rectangle {
        implicitWidth: parent.width
        implicitHeight: 32
        color: COMMON.bg2
        DialogButtonBox {
            id: buttonBox
            anchors.centerIn: parent
            standardButtons: dialog.standardButtons
            alignment: Qt.AlignHCenter
            spacing: 5

            background: Item {
                implicitHeight: 22
            }

            delegate: Button {
                id: control
                implicitHeight: 22

                contentItem: SText {
                    id: contentText
                    color: COMMON.fg1
                    text: control.text
                    pointSize: 9
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    radius: 0
                    color: control.down ? COMMON.bg4 : COMMON.bg3_5
                    border.color: control.hovered ? COMMON.bg6 : COMMON.bg5
                }
            }

            Keys.onReleased: {
                event.accepted = true
                switch(event.key) {
                    case Qt.Key_Enter:
                    case Qt.Key_Return:
                        dialog.accept()
                        break;
                    default:
                        event.accepted = false
                        break;
                }
            }

            onAccepted: dialog.accept()
            onRejected: dialog.reject()
        }
    }
}