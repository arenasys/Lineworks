import QtQuick 2.15
import QtQuick.Controls 2.15
import QtGraphicalEffects 1.12
import QtQuick.Layouts 1.15

import gui 1.0

import "style"
import "components"

FocusReleaser {
    id: focus
    property var window
    property var active: window != null ? window.active : false
    anchors.fill: parent

    onActiveChanged: {
        GUI.windowActive = active
    }

    Timer {
        interval: 50
        onTriggered: {
            GUI.resetFocus()
        }
        running: true
    }
    
    Component.onCompleted: {
        window.title = Qt.binding(function() { return GUI.title; })
        COMMON.scheme = Qt.binding(function() { return GUI.colorScheme; })
        GUI.ready()
    }
    
    Rectangle {
        id: root
        anchors.fill: parent
        color: COMMON.light ? COMMON.bg2 : COMMON.bg0
    }

    WindowBar {
        id: windowBar
        anchors.left: root.left
        anchors.right: root.right

        function showPreferences() {
            preferences.open()
        }

        function showUpdate() {
            GUI.update()
            preferences.open()
        }
    }

    Item {
        id: main
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: windowBar.bottom
        anchors.topMargin: 1
        height: Math.max(200, parent.height - windowBar.height)

        SShadow {
            color: COMMON.bg0
            anchors.fill: parent
            anchors.margins: -1
        }

        WorkingLine {
            id: saveIndicator
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: 1
            height: 2
            visible: false
            advance: 0.05

            Connections {
                target: GUI
                function onSaving() {
                    saveIndicator.visible = true
                    saveIndicatorTimer.start()
                }
            }
            
            Timer {
                id: saveIndicatorTimer
                interval: 300
                onTriggered: {
                    parent.visible = false
                }
            }
        }

        Timer {
            id: autosaveTimer
            running: GUI.file != ""
            interval: 1000 * 120
            repeat: true
            onTriggered: {
                GUI.autosave()
            }
        }

        Item {
            id: textColumn
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: paramColumn.left
            anchors.topMargin: 10
            anchors.bottomMargin: 10
            width: Math.max(200, parent.width - 400)

            RectangularGlow {
                anchors.fill: parent
                glowRadius: 5
                opacity: 0.25
                spread: 0.2
                color: "black"
                cornerRadius: 10
            }
            
            Rectangle {
                anchors.fill: parent
                color: COMMON.light ? COMMON.bg0_5 : COMMON.bg00
                border.color: COMMON.light ? COMMON.bg4 : COMMON.bg2
                border.width: 1
            }

            Item {
                anchors.fill: parent
                anchors.margins: 5
                clip: true

                SDividerVR {
                    color: "transparent"
                    id: verticalDivider
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 5
                    minOffset: 50
                    maxOffset: parent.width-55
                    offset: parent.width/2
                    snap: parent.width/2
                    snapSize: 20
                }

                SDividerHB {
                    color: "transparent"
                    id: horizontalDivider
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 5

                    minOffset: 50
                    maxOffset: parent.height-55
                    offset: parent.height/2
                    snap: parent.height/2
                    snapSize: 20
                }

                Repeater {
                    model: ArrayModel {
                        source: GUI.tabs.areas
                        unique: true
                    }
                    TabArea {
                        hDivider: horizontalDivider
                        vDivider: verticalDivider
                        area: model.data
                        function releaseFocus() {
                            keyboardFocus.forceActiveFocus()
                        }
                    }
                }
            }
        }

        Item {
            id: paramColumn
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.topMargin: 25
            anchors.bottomMargin: 25
            width: 200

            Column {
                anchors.fill: parent
                anchors.margins: 10

                Item {
                    width: parent.width
                    height: 25 + (25*(GUI.isAPI ? 2 : 4)) + 3

                    RectangularGlow {
                        anchors.fill: parent
                        glowRadius: 5
                        opacity: 0.25
                        spread: 0.2
                        color: "black"
                        cornerRadius: 10
                    }

                    Rectangle {
                        anchors.fill: parent
                        color:  COMMON.light ? COMMON.bg2 : COMMON.bg1
                        border.color: COMMON.bg4
                    }

                    Rectangle {
                        color: COMMON.light ? COMMON.bg1_5 : COMMON.bg2
                        border.color: COMMON.bg4
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 25

                        SText {
                            height: parent.height
                            leftPadding: 5
                            verticalAlignment: Text.AlignVCenter
                            text: "Model"
                            color: COMMON.fg1_5
                            pointSize: 10.2
                        }

                        SIcon {
                            visible: GUI.modelIsAltered
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: modelIcon.left
                            anchors.rightMargin: -5
                            width: height
                            iconColor: mouse.containsMouse ? COMMON.bg7 : COMMON.bg4
                            inset: 10
                            tooltip: pressed ? "Reset?" : "Options changed"
                            icon: "qrc:/icons/warning.svg"

                            property var pressed: false
                            mouse.onPressed: {
                                if(!pressed) {
                                    pressed = true
                                } else {
                                    GUI.resetModel()
                                }
                            }
                            mouse.onExited: {
                                pressed = false
                            }
                        }

                        SIcon {
                            id: modelIcon
                            visible: !GUI.modelIsWorking && !GUI.modelIsLoaded
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                            iconColor: COMMON.bg4
                            tooltip: "No model loaded"
                            icon: "qrc:/icons/dash.svg"
                            smooth: false
                        }

                        SIcon {
                            visible: !GUI.modelIsWorking && GUI.modelIsLoaded
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                            iconColor: COMMON.bg4
                            tooltip: GUI.currentModel
                            icon: "qrc:/icons/tick.svg" 
                            inset: 8
                        }

                        LoadingSpinner {
                            visible: GUI.modelIsWorking
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.topMargin: 25

                        SChoice {
                            height: 25
                            width: parent.width
                            label: "Name"
                            bindMap: GUI.modelParameters
                            bindKeyCurrent: "model_path"
                            bindKeyModel: "model_paths"

                            function display(text) {
                                return GUI.getName(text)
                            }

                            override: value == "" ? "No models" : ""
                        }

                        SSlider {
                            visible: !GUI.isAPI
                            height: visible ? 25 : 0
                            width: parent.width
                            label: "Layer offload"
                            minValue: 0
                            maxValue: 128
                            precValue: 0
                            incValue: 1
                            snapValue: 8
                            bounded: true
                            disabled: GUI.device == "cpu"

                            tooltip: disabled ? "Using CPU only" : ""

                            override: disabled ? "None" : (!active ? (value == "128" ? "Full" : (value == "0" ? "None" : "")) : "")

                            bindMap: GUI.modelParameters
                            bindKey: "n_gpu_layers"
                        }

                        SSlider {
                            height: 25
                            width: parent.width
                            label: "Context length"
                            minValue: 512
                            maxValue: 8196
                            precValue: 0
                            incValue: 256
                            snapValue: 256
                            bounded: false

                            bindMap: GUI.modelParameters
                            bindKey: "n_ctx"
                        }

                        Item {
                            visible: !GUI.isAPI
                            height: visible ? 4 : 0
                            width: parent.width
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 1
                                height: 1
                                width: parent.width
                                color: COMMON.bg4
                            }
                        }

                        Row {
                            visible: !GUI.isAPI
                            height: visible ? 22 : 0
                            width: parent.width
                            

                            leftPadding: 1
                            rightPadding: 1
                            spacing: -1

                            SButton {
                                height: 22
                                width: parent.width/2
                                label: GUI.modelIsAltered ? "Reload" : "Load"
                                disabled: GUI.modelIsWorking || (GUI.modelIsLoaded && !GUI.modelIsAltered)
                                color: COMMON.fg1_5

                                onPressed: {
                                    GUI.load()
                                }
                            }

                            SButton {
                                height: 22
                                width: parent.width/2 - 1
                                label: "Unload"
                                disabled: GUI.modelIsWorking || !GUI.modelIsLoaded
                                color: COMMON.fg1_5

                                onPressed: {
                                    GUI.unload()
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 10
                }

                Item {
                    width: parent.width
                    height: 25 + (25*(minPSlider.active ? 4 : (!GUI.isAPI ? 6 : 5))) + 3 + 3

                    RectangularGlow {
                        anchors.fill: parent
                        glowRadius: 5
                        opacity: 0.25
                        spread: 0.2
                        color: "black"
                        cornerRadius: 10
                    }

                    Rectangle {
                        anchors.fill: parent
                        color:  COMMON.light ? COMMON.bg2 : COMMON.bg1
                        border.color: COMMON.bg4
                    }

                    Rectangle {
                        color: COMMON.light ? COMMON.bg1_5 : COMMON.bg2
                        border.color: COMMON.bg4
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 25

                        SIcon {
                            visible: GUI.presetIsAltered
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: genIcon.left
                            anchors.rightMargin: -5
                            width: height
                            iconColor: COMMON.bg4
                            inset: 10
                            tooltip: pressed ? "Reset?" : "Options changed"
                            icon: "qrc:/icons/warning.svg"

                            property var pressed: false
                            mouse.onPressed: {
                                if(!pressed) {
                                    pressed = true
                                } else {
                                    GUI.resetPreset()
                                }
                            }
                            mouse.onExited: {
                                pressed = false
                            }
                        }

                        SIconButton {
                            id: genIcon
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                            color: "transparent"
                            iconColor: genMenu.opened ? COMMON.bg7 : COMMON.bg4
                            iconHoverColor: COMMON.bg7
                            icon: "qrc:/icons/menu-dots.svg"
                            smooth: false
                            inset: 8

                            onPressed: {
                                genMenu.popup(parent.width-genMenu.width, 24)
                            }
                        }

                        SMenu {
                            id: genMenu
                            width: 80
                            clipShadow: true
                            SMenuItem {
                                text: "Save"
                                onPressed: {
                                    GUI.savePreset()
                                }
                            }
                            SMenuItem {
                                text: "New"
                                onPressed: {
                                    GUI.newPreset()
                                }
                            }
                            SMenuItem {
                                text: "Rename"
                                onPressed: {
                                    presetChoice.edit()
                                }
                            }
                            SMenuItem {
                                text: "Delete"
                                onPressed: {
                                    GUI.deletePreset()
                                }
                            }
                        }

                        SText {
                            height: parent.height
                            leftPadding: 5
                            verticalAlignment: Text.AlignVCenter
                            text: "Parameters"
                            color: COMMON.fg1_5
                            pointSize: 10.2
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.topMargin: 25

                        SChoice {
                            id: presetChoice
                            height: 25
                            width: parent.width
                            label: "Preset"
                            bindMap: GUI.generatePresets
                            bindKeyCurrent: "preset"
                            bindKeyModel: "presets"
                            readonly: false

                            onEdited: {
                                GUI.renamePreset(newValue, oldValue)
                            }
                        }

                        Item {
                            height: 3
                            width: parent.width
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 0
                                height: 1
                                width: parent.width
                                color: COMMON.bg4
                            }
                        }

                        SSlider {
                            height: 25
                            width: parent.width
                            label: "Temperature"
                            minValue: 0
                            maxValue: 2
                            precValue: 2
                            incValue: 0.01
                            snapValue: 0.05
                            bounded: false

                            bindMap: GUI.generateParameters
                            bindKey: "temperature"
                        }

                        SSlider {
                            id: minPSlider
                            visible: !GUI.isAPI
                            height: visible ? 25 : 0
                            property var active: minPSlider.value != 0.0 && !GUI.isAPI

                            width: parent.width
                            label: "Min P"
                            minValue: 0
                            maxValue: 1
                            precValue: 2
                            incValue: 0.01
                            snapValue: 0.05
                            bounded: true
                            overlay: !active

                            bindMap: GUI.generateParameters
                            bindKey: "min_p"
                        }

                        SSlider {
                            height: minPSlider.active ? 0 : 25
                            width: parent.width
                            visible: height != 0
                            label: "Top P"
                            minValue: 0
                            maxValue: 1
                            precValue: 2
                            incValue: 0.01
                            snapValue: 0.05
                            bounded: true

                            bindMap: GUI.generateParameters
                            bindKey: "top_p"
                        }

                        SSlider {
                            height: minPSlider.active ? 0 : 25
                            width: parent.width
                            visible: height != 0
                            label: "Top K"
                            minValue: 0
                            maxValue: 200
                            precValue: 0
                            incValue: 1
                            snapValue: 5
                            bounded: false

                            bindMap: GUI.generateParameters
                            bindKey: "top_k"
                        }

                        SSlider {
                            height: 25
                            width: parent.width
                            label: "Repeat penalty"
                            minValue: 0
                            maxValue: 1.5
                            precValue: 2
                            incValue: 0.01
                            snapValue: 0.05
                            bounded: false

                            bindMap: GUI.generateParameters
                            bindKey: "repeat_penalty"
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 10
                }

                Item {
                    width: parent.width
                    height: 25 + (25*3) + 3

                    RectangularGlow {
                        anchors.fill: parent
                        glowRadius: 5
                        opacity: 0.25
                        spread: 0.2
                        color: "black"
                        cornerRadius: 10
                    }

                    Rectangle {
                        anchors.fill: parent
                        color:  COMMON.light ? COMMON.bg2 : COMMON.bg1
                        border.color: COMMON.bg4
                    }

                    Rectangle {
                        color: COMMON.light ? COMMON.bg1_5 : COMMON.bg2
                        border.color: COMMON.bg4
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 25

                        LoadingSpinner {
                            visible: GUI.isGenerating
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                        }

                        SText {
                            height: parent.height
                            leftPadding: 5
                            verticalAlignment: Text.AlignVCenter
                            text: "Generation"
                            color: COMMON.fg1_5
                            pointSize: 10.2
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.topMargin: 25

                        SSlider {
                            height: 25
                            width: parent.width
                            label: "Max Tokens"
                            minValue: 1
                            maxValue: 1024
                            precValue: 0
                            incValue: 1
                            snapValue: 16
                            bounded: false

                            bindMap: GUI.stopParameters
                            bindKey: "max_tokens"
                        }

                        SChoice {
                            height: 25
                            width: parent.width
                            label: "Stop Condition"
                            bindMap: GUI.stopParameters
                            bindKeyCurrent: "stop_condition"
                            bindKeyModel: "stop_conditions"
                        }

                        Item {
                            height: 3
                            width: parent.width
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 0
                                height: 1
                                width: parent.width
                                color: COMMON.bg4
                            }
                        }

                        Item {
                            height: 24
                            width: parent.width

                            SButton {
                                anchors.fill: parent
                                anchors.margins: 1
                                label: GUI.isGenerating ? "Abort" : "Go"
                                color: COMMON.fg1_5
                                disabled: !GUI.modelIsLoaded

                                onPressed: {
                                    if(GUI.isGenerating) {
                                        GUI.abort()
                                    } else {
                                        GUI.generate()
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: 10
                }

                Item {
                    width: parent.width
                    height: 25 + (backendMode.value == "Remote" ? (25*3 + 6) : 25 + 3)

                    RectangularGlow {
                        anchors.fill: parent
                        glowRadius: 5
                        opacity: 0.25
                        spread: 0.2
                        color: "black"
                        cornerRadius: 10
                    }

                    Rectangle {
                        anchors.fill: parent
                        color:  COMMON.light ? COMMON.bg2 : COMMON.bg1
                        border.color: COMMON.bg4
                    }

                    Rectangle {
                        color: COMMON.light ? COMMON.bg1_5 : COMMON.bg2
                        border.color: COMMON.bg4
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 25

                        LoadingSpinner {
                            visible: GUI.isConnecting
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                            tooltip: "Connecting..."
                        }

                        SIcon {
                            visible: backendMode.value == "Local"
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                            iconColor: COMMON.bg4
                            tooltip: "Using local hardware"
                            icon: "qrc:/icons/dash.svg"
                            smooth: false
                        }

                        SIcon {
                            visible: backendMode.value == "Remote"
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: restartButton.left
                            width: height
                            iconColor: GUI.isConnected ? COMMON.accent(0, 0.6, 0.5) : COMMON.bg4
                            tooltip: GUI.isConnected ? "Connected" : "Not connected"
                            icon: GUI.isConnected ? "qrc:/icons/lightning.svg" : "qrc:/icons/dash.svg"
                        }

                        SIconButton {
                            id: restartButton
                            visible: backendMode.value == "Remote" && !GUI.isConnecting
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                            color: "transparent"
                            iconColor: COMMON.bg4
                            iconHoverColor: COMMON.bg7
                            tooltip: GUI.isConnected ? "Reconnect?" : "Connect?"
                            icon: "qrc:/icons/refresh.svg"
                        }

                        RotationAnimator {
                            loops: Animation.Infinite
                            target: restartButton
                            from: 0
                            to: -360
                            duration: 1000
                            running: GUI.isConnecting && GUI.windowActive
                            onRunningChanged: {
                                restartButton.rotation = 0
                            }
                        }

                        MouseArea {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height

                            onPressed: {
                                if(backendMode.value == "Remote") {
                                    GUI.restartBackend()
                                }
                            }
                        }

                        SText {
                            height: parent.height
                            leftPadding: 5
                            verticalAlignment: Text.AlignVCenter
                            text: "Backend"
                            color: COMMON.fg1_5
                            pointSize: 10.2
                        }
                    }

                    Column {
                        anchors.fill: parent
                        anchors.topMargin: 25

                        SChoice {
                            id: backendMode
                            height: 25
                            width: parent.width
                            label: "Mode"
                            bindMap: GUI.backendParameters
                            bindKeyCurrent: "mode"
                            bindKeyModel: "modes"
                        }

                        Item {
                            visible: backendMode.value == "Remote"
                            height: 3
                            width: parent.width
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 0
                                height: 1
                                width: parent.width
                                color: COMMON.bg4
                            }
                        }

                        SInput {
                            visible: backendMode.value == "Remote"
                            height: 25
                            width: parent.width
                            label: "Endpoint"
                            bindMap: GUI.backendParameters
                            bindKey: "endpoint"
                            override: !active ? (value == "" ? "URL" : "") : ""
                            pointSize: 9.0
                            blankReset: false
                        }

                        SInput {
                            visible: backendMode.value == "Remote"
                            height: 25
                            width: parent.width
                            label: "Key"
                            bindMap: GUI.backendParameters
                            bindKey: "key"
                            override: !active ? (value == "" ? "None" : "") : ""
                            pointSize: 9.0
                            blankReset: false
                        }
                    }
                }
            }
        }    

        MouseArea {
            visible: preview.locked
            anchors.fill: parent
            onPressed: {
                preview.locked = false
                preview.target = null
                mouse.accepted = false
            }
        }

        Item {
            id: historyColumn
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: textColumn.left
            anchors.topMargin: 25
            anchors.bottomMargin: 25
            width: 200

            Item {
                anchors.fill: parent
                anchors.margins: 10
                anchors.rightMargin: 10

                RectangularGlow {
                    anchors.fill: parent
                    glowRadius: 5
                    opacity: 0.25
                    spread: 0.2
                    color: "black"
                    cornerRadius: 10
                }

                Rectangle {
                    anchors.fill: parent
                    color: COMMON.light ? COMMON.bg2 : COMMON.bg1
                    border.color: COMMON.bg4
                }

                Rectangle {
                    color: COMMON.bg2
                    border.color: COMMON.bg4
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 25

                    SText {
                        height: parent.height
                        leftPadding: 5
                        verticalAlignment: Text.AlignVCenter
                        text: "History"
                        color: COMMON.fg1_5
                        pointSize: 10.2
                    }
                }

                Rectangle {
                    anchors.fill: historyList
                    color: COMMON.light ? COMMON.bg1 : COMMON.bg0_5
                    border.color: COMMON.bg4
                    anchors.margins: -1
                }

                Item {
                    height: historyList.height - historyList.contentHeight

                    anchors.left: historyList.left
                    anchors.right: historyList.right
                    anchors.bottom: historyList.bottom
                    SIcon {
                        icon: "qrc:/icons/placeholder-black.svg"
                        anchors.centerIn: parent
                        iconColor: COMMON.bg3
                        width: 50
                        height: 50
                        visible: parent.height > 100
                        opacity: Math.max(0.0, (parent.height-100)/200)
                        img.visible: false
                    }
                }

                Rectangle {
                    id: searchBox
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: 23
                    anchors.margins: 5
                    anchors.topMargin: 29
                    color: COMMON.bg2
                    border.color: COMMON.bg4

                    STextInput {
                        id: searchInput
                        anchors.fill: parent
                        color: COMMON.fg1
                        font.bold: false
                        pointSize: 9.0
                        selectByMouse: true
                        verticalAlignment: Text.AlignVCenter
                        leftPadding: 8
                        topPadding: 1

                        function search() {
                            GUI.searchHistory(searchInput.text)
                        }

                        onAccepted: {
                            search()
                        }

                        Keys.onPressed: {
                            switch(event.key) {
                            case Qt.Key_Escape:
                                searchInput.text = ""
                                search()
                                GUI.resetFocus()
                                break;
                            }
                        }

                        Connections {
                            target: GUI
                            function onClear() {
                                searchInput.text = ""
                            }
                        }
                    }

                    SText {
                        text: "Search..."
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        font.bold: false
                        pointSize: COMMON.pointLabel
                        leftPadding: 8
                        topPadding: 1
                        color: COMMON.fg2
                        visible: !searchInput.text && !searchInput.activeFocus
                    }
                }

                ListView {
                    anchors.fill: parent
                    anchors.topMargin: 57
                    anchors.margins: 6
                    id: historyList
                    interactive: false
                    boundsBehavior: Flickable.StopAtBounds                   
                    width: parent.width
                    clip: true
                    model: ArrayModel {
                        source: GUI.history
                        unique: true
                    }

                    ScrollBar.vertical: SScrollBarV { 
                        id: historyScrollBar
                        anchors.right: historyList.right
                        anchors.rightMargin: -2
                        barWidth: 5
                        color: COMMON.bg3
                        hoverColor: COMMON.bg4
                        pressedColor: COMMON.bg5
                        policy: historyList.contentHeight > historyList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                        property var line: 1/(Math.ceil(historyList.model.count))
                        stepSize: line
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        property var bar: historyScrollBar
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

                    property var nextIndex: -1

                    delegate: Rectangle {
                        id: row
                        property var entry: GUI.getHistory(model.data)
                        property var active: preview.locked && preview.target == entry

                        color: active ? COMMON.bg2_5 : (entryMouse.containsMouse ? COMMON.bg2 : COMMON.bg1_5)
                        height: 20
                        width: parent != null ? parent.width - (historyList.contentHeight > historyList.height ? 6 : 0)  : 20 

                        function activate() {
                            preview.target = entry
                            preview.center = preview.parent.mapFromItem(entryMouse, Qt.point(0, entryMouse.height/2)).y
                            previewClear.stop()
                        }

                        function sync() {
                            if(active) {
                                preview.center = preview.parent.mapFromItem(entryMouse, Qt.point(0, entryMouse.height/2)).y
                            }
                        }

                        onYChanged: {
                            sync()
                        }

                        Rectangle {
                            anchors.fill: indexLabel
                            color: COMMON.bg2_5
                        }

                        SText {
                            id: indexLabel
                            anchors.left: parent.left
                            height: parent.height
                            width: 2+Math.floor(Math.log10(GUI.history.length)+1)*9
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: entry ? entry.index : ""
                            pointSize: 9.0
                            color: COMMON.fg2
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: indexLabel.right
                            width: 1
                            color: COMMON.bg4
                        }

                        SText {
                            id: entryLabel
                            anchors.left: indexLabel.right
                            anchors.leftMargin: 1
                            anchors.right: parent.right
                            height: parent.height
                            leftPadding: 3
                            rightPadding: 1
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignLeft
                            text: entry ? entry.label : ""
                            pointSize: 9.0
                            color: COMMON.fg1_5
                            elide: Text.ElideRight
                            textFormat: Text.PlainText
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: COMMON.bg4
                        }

                        Rectangle {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: 1
                            anchors.rightMargin: -1
                            color: COMMON.bg4
                        }

                        Rectangle {
                            anchors.fill: parent
                            visible: active
                            color: "transparent"
                            border.color: COMMON.bg0
                            anchors.margins: 0
                            anchors.bottomMargin: 1

                            Rectangle {
                                anchors.fill: parent
                                visible: active
                                color: "transparent"
                                border.color: COMMON.accent(0, 0.6, 0.35)
                                anchors.margins: 1
                            }
                        }

                        SContextMenu {
                            id: entryContextMenu
                            width: 120
                            SContextMenuItem {
                                text: "Copy"
                                onPressed: {

                                }
                            }
                            SMenuSeparator { }
                            SContextMenuItem {
                                text: "Clear"
                                onPressed: {
                                    preview.locked = false
                                    row.entry = null
                                    GUI.clearHistoryEntries([model.data])
                                }
                            }
                            SContextMenuItem {
                                text: "Clear below"
                                disabled: searchInput.text != "" || index == historyList.count-1

                                onPressed: {
                                    GUI.clearHistoryEntriesBelow(model.data)
                                    searchInput.text = ""
                                    searchInput.search()
                                }
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.RightButton

                            onPressed: {
                                if(mouse.buttons & Qt.RightButton) {
                                    entryContextMenu.popup()
                                }
                            }
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            property var startPosition: Qt.point(0,0)
                            property var dragged: false
                            acceptedButtons: Qt.LeftButton

                            onClicked: {
                                startPosition = Qt.point(mouse.x, mouse.y)

                                if(row.active) {
                                    preview.locked = false
                                } else {
                                    row.forceActiveFocus()
                                    preview.locked = true
                                    activate()
                                }
                            }

                            onEntered: {
                                if(!preview.locked) {
                                    row.activate()
                                }
                            }

                            onExited: {
                                if(!preview.locked) {
                                    previewClear.start()
                                }
                            }

                            Timer {
                                id: historyDragCooldown
                                interval: 50
                            }

                            onPositionChanged: {
                                if(pressedButtons & Qt.LeftButton) {
                                    var delta = Qt.point(mouse.x-startPosition.x, mouse.y-startPosition.y)
                                    if(Math.pow(delta.x*delta.x + delta.y*delta.y, 0.5) > 15) {
                                        if(!historyDragCooldown.running) {
                                            preview.locked = false
                                            GUI.tabs.dragHistory(entry.id)
                                            historyDragCooldown.start()
                                        }
                                    }
                                }
                            }
                        }

                        Connections {
                            target: historyList
                            function onNextIndexChanged() {
                                if(historyList.nextIndex == index) {
                                    row.forceActiveFocus()
                                    preview.locked = true
                                    row.activate()
                                }
                            }

                            function onContentYChanged() {
                                row.sync()
                            }
                        }

                        Keys.onPressed: {
                            event.accepted = true
                            switch(event.key) {
                            case Qt.Key_Up:
                                historyList.nextIndex = index - 1
                                break;
                            case Qt.Key_Down:
                                historyList.nextIndex = index + 1
                                break;
                            case Qt.Key_Escape:
                                preview.locked = false
                                previewClear.start()
                                break;
                            default:
                                event.accepted = false
                                break;
                            }
                        }
                    }
                }
            }

            RectangularGlow {
                anchors.fill: preview
                anchors.margins: -1
                visible: preview.visible
                glowRadius: 5
                opacity: 0.25
                spread: 0.2
                color: "black"
                cornerRadius: 10
            }

            Rectangle {
                id: previewBg
                visible: preview.visible
                anchors.fill: preview
                anchors.margins: -1
                color: COMMON.bg0

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    color: COMMON.bg1
                }
            }

            STextArea {
                id: preview
                property var center: 0
                y: Math.min(parent.height - height, Math.max(0, center - height/2))
                anchors.left: parent.right
                anchors.leftMargin: -5
                width: 300
                height: Math.min(area.contentHeight+10, 100)
                area.padding: 5
                area.leftPadding: 6
                area.rightPadding: 10
                readOnly: true
                pointSize: 9.6
                clip: true
                visible: target != null
                opacity: locked ? 1.0 : 0.8
                area.textFormat: Text.RichText

                property var target: null
                property var locked: false

                Timer {
                    id: previewClear
                    interval: 50
                    onTriggered: {
                        if(!preview.locked) {
                            preview.target = null
                        }
                    }
                }

                area.onActiveFocusChanged: {
                    if(area.activeFocus) {
                        previewClear.stop()
                    }
                }

                onTargetChanged: {
                    if(preview.target) {
                        preview.text = preview.target.context + preview.target.output
                    }
                }

                area.onTextChanged: {
                    layout()
                    if(control.contentHeight > control.height) {
                        control.contentY = control.contentHeight-control.height
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    hoverEnabled: true
                    onEntered: {
                        previewClear.stop()
                    }
                    onExited: {
                        previewClear.start()
                    }
                }
            }

            Rectangle {
                visible: preview.visible
                anchors.fill: previewBg
                anchors.margins: 1
                color: "transparent"
                border.color: COMMON.bg4
                opacity: preview.locked ? 1.0 : 0.8
            }

            Rectangle {
                anchors.fill: previewBg
                anchors.margins: 1
                visible: preview.visible && preview.locked
                color: "transparent"
                opacity: 0.3
                border.color: COMMON.accent(0)
            }
        }

        Preferences {
            id: preferences
        }

        SDialog {
            id: errorDialog
            title: "Error"
            standardButtons: Dialog.Ok
            modal: true
            property var status: ""
            property var error: ""

            Connections {
                target: GUI
                function onErrored(error, status) {
                    errorDialog.error = error
                    errorDialog.status = status
                    errorDialog.open()
                }
            }

            height: Math.max(80, errorMessage.height + 60)
            width: 300

            SText {
                id: errorMessage
                anchors.centerIn: parent
                padding: 5
                text: "Error while %1.\n%2".arg(errorDialog.status).arg(errorDialog.error)
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
                width: parent.width
                wrapMode: Text.Wrap
                color: COMMON.fg1
            }

            onClosed: {
                root.forceActiveFocus()
            }
        }
    }

    OpacityAnimator {
        target: parent
        from: 0
        to: 1
        duration: 100
        running: true
    }

    onReleaseFocus: {
        GUI.resetFocus()
    }

    Item {
        id: keyboardFocus
        Keys.onPressed: {
            event.accepted = false
        }
        Keys.forwardTo: [main]
    }
}