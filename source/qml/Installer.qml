import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.12
import QtQuick.Layouts 1.15

import gui 1.0

import "style"
import "components"

FocusReleaser {
    id: root
    anchors.fill: parent

    Connections {
        target: COORDINATOR
        function onProceed() {
            button.disabled = true
        }
    }

    Rectangle {
        anchors.fill: parent
        color: COMMON.bg00
    
        Column {
            anchors.centerIn: parent
            width: 300
            height: parent.height - 200

            SText {
                text: "Requirements"
                width: parent.width
                height: 40
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                pointSize: 10.8
                color: COMMON.fg1
            }

            SChoice {
                id: choice
                width: 300
                height: 25
                label: "Mode"
                disabled: COORDINATOR.disable
                currentIndex: COORDINATOR.mode
                model: COORDINATOR.modes
                onCurrentIndexChanged: {
                    currentIndex = currentIndex
                    COORDINATOR.mode = currentIndex
                }
            }

            Item {
                width: 300
                height: 200
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 2
                    anchors.bottomMargin: 0
                    border.color: COMMON.bg4
                    color: "transparent"
                    
                    ListView {
                        id: packageList
                        anchors.fill: parent
                        anchors.margins: 1
                        clip: true
                        model: COORDINATOR.packages
                        boundsBehavior: Flickable.StopAtBounds

                        ScrollBar.vertical: SScrollBarV {
                            id: scrollBar
                            parent: packageList
                            anchors.right: packageList.right
                            anchors.rightMargin: -2
                            barWidth: 5
                            color: COMMON.bg3
                            hoverColor: COMMON.bg4
                            pressedColor: COMMON.bg5
                            policy: packageList.contentHeight > packageList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        }

                        Rectangle {
                            width: 5
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.rightMargin: 0
                            color: COMMON.bg0_5
                            visible: packageList.contentHeight > packageList.height
                        }

                        Rectangle {
                            width: 1
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            anchors.rightMargin: 5
                            color: COMMON.bg4
                            visible: packageList.contentHeight > packageList.height
                        }

                        delegate: Rectangle {

                            color: (index % 2 == 0 ? COMMON.bg0 : COMMON.bg00)
                            width: packageList.width
                            height: modelData == "pip" || modelData == "wheel" ? 0 : 20

                            Rectangle {
                                color: "green"
                                anchors.fill: parent
                                opacity: 0.1
                                visible: COORDINATOR.installed.includes(modelData)
                            }

                            Rectangle {
                                color: "yellow"
                                anchors.fill: parent
                                opacity: 0.1
                                visible: COORDINATOR.installing == modelData
                                onVisibleChanged: {
                                    if(visible) {
                                        packageList.positionViewAtIndex(index, ListView.Contain)
                                    }
                                }
                            }

                            SText {
                                text: modelData.split(" @ ")[0]
                                width: parent.width
                                height: 20
                                verticalAlignment: Text.AlignVCenter
                                horizontalAlignment: Text.AlignHCenter
                                pointSize: 9.8
                                color: COMMON.fg1
                            }
                        }
                    }
                }
            }

            SButton {
                id: button
                width: 300
                height: 25
                label: COORDINATOR.disable ? "Cancel" : (COORDINATOR.packages.length == 0 ? "Proceed" : "Install")
                
                onPressed: {
                    if(!COORDINATOR.disable) {
                        outputArea.text = ""
                    }
                    COORDINATOR.install()
                }   
            }

            SText {
                visible: COORDINATOR.needRestart
                text: "Restart required"
                width: parent.width
                height: 30
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
                pointSize: 9.8
                color: COMMON.fg2
            }

            Item {
                width: parent.width
                height: 30
            }

            Item {
                x: -parent.width
                width: parent.width*3
                height: 120

                STextArea {
                    id: outputArea
                    anchors.fill: parent
                    anchors.topMargin: 1
                    anchors.bottomMargin: 1

                    area.color: COMMON.fg2
                    pointSize: 9.8
                    monospace: true

                    Connections {
                        target: COORDINATOR
                        function onOutput(output) {
                            outputArea.text += output + "\n"
                            outputArea.area.cursorPosition = outputArea.text.length-1
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    border.width: 1
                    border.color: COMMON.bg4
                    color: "transparent"
                }
            }

        }
    }
}