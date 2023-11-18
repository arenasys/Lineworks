import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

import gui 1.0
import "../style"

SDialog {
    id: root
    anchors.centerIn: parent
    standardButtons: Dialog.Ok
    title: "Preferences"
    modal: true
    
    property alias index: stack.currentIndex
    property var tabs: ["Program"]

    height: 300
    width: 500

    Rectangle {
        anchors.margins: 0
        anchors.fill: parent
        color: COMMON.bg1
        border.color: COMMON.bg4

        Rectangle {
            id: column
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: 150
            color: COMMON.bg1
            anchors.margins: 1

            Rectangle {
                color: COMMON.bg0_5
                border.color: COMMON.bg4
                anchors.fill: parent
                anchors.margins: 5
                anchors.leftMargin: 5
                anchors.rightMargin: 5
            }

            Column {
                anchors.fill: parent
                anchors.margins: 5
                spacing: 5
                topPadding: 5
                Repeater {
                    model: root.tabs

                    Rectangle {
                        width: parent.width
                        height: 25
                        color: stack.currentIndex == index ? COMMON.bg3 : COMMON.bg2
                        border.color: (mouseArea.containsMouse || stack.currentIndex == index) ? COMMON.bg5 : COMMON.bg4

                        SText {
                            text: modelData
                            anchors.fill: parent

                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter

                            color: stack.currentIndex == index ? COMMON.fg1_5 : COMMON.fg2
                            pointSize: COMMON.pointLabel

                        }

                        MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true

                            onPressed: {
                                stack.currentIndex = index
                            }

                        }
                    }
                }
            }
        }

        Rectangle {
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.left: column.right
            anchors.right: parent.right

            anchors.margins: 6
            anchors.leftMargin: 0

            color: COMMON.bg0_5
            border.color: COMMON.bg4

            StackLayout {
                id: stack
                anchors.fill: parent

                Item {
                    Column {
                        height: parent.height
                        width: 250
                        anchors.centerIn: parent
                        topPadding: 95

                        SButton {
                            label: updateSpinner.visible ? "Updating..." : "Update"
                            disabled: restartLabel.visible
                            width: parent.width
                            height: 25
                            color: COMMON.fg1_5

                            onPressed: {
                                if(versionLabel.visible) {
                                    GUI.update()
                                }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 20

                            STextSelectable {
                                id: versionLabel
                                visible: !updateSpinner.visible && !restartLabel.visible
                                anchors.fill: parent

                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter

                                color: COMMON.fg2
                                monospace: true
                                pointSize: 8.5
                                text: GUI.versionInfo
                            }

                            SText {
                                id: restartLabel
                                visible: GUI.needRestart
                                anchors.fill: parent

                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter

                                color: "#ee2222"
                                opacity: 0.6
                                monospace: true
                                pointSize: 9.0
                                text: "Restart required"
                            }

                            SIcon {
                                id: updateSpinner
                                visible: GUI.updating
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: height
                                iconColor: null
                                opacity: 0.5
                                inset: 1
                                icon: "qrc:/icons/loading-big.svg"
                            }

                            RotationAnimator {
                                loops: Animation.Infinite
                                target: updateSpinner
                                from: 0
                                to: 360
                                duration: 1000
                                running: parent.visible
                            }
                        }

                        Item {
                            width: parent.width
                            height: 25
                        }
                    }
                }
            }
        }
    }
}