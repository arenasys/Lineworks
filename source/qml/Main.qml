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
    anchors.fill: parent  
    
    Component.onCompleted: {
        window.title = Qt.binding(function() { return GUI.title; })
    }

    Rectangle {
        id: root
        anchors.fill: parent
        color: COMMON.bg0
    }

    WindowBar {
        id: windowBar
        anchors.left: root.left
        anchors.right: root.right
    }

    Item {
        id: main
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: windowBar.bottom
        height: Math.max(200, parent.height - windowBar.height)

        SShadow {
            color: COMMON.bg0
            anchors.fill: parent
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
                color: COMMON.bg00
                border.color: COMMON.bg2
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
                    model: GUI.tabs.areas
                    TabArea {
                        hDivider: horizontalDivider
                        vDivider: verticalDivider
                        area: modelData
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
                    height: 25 + (25*4) + 3

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
                        color: COMMON.bg1
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

                        SIcon {
                            id: modelSpinner
                            visible: GUI.modelIsWorking
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                            iconColor: null
                            opacity: 0.5
                            icon: "qrc:/icons/loading-big.svg"
                        }

                        RotationAnimator {
                            loops: Animation.Infinite
                            target: modelSpinner
                            from: 0
                            to: 360
                            duration: 1000
                            running: parent.visible
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
                        }

                        SSlider {
                            height: 25
                            width: parent.width
                            label: "Layer offload"
                            minValue: 0
                            maxValue: 128
                            precValue: 0
                            incValue: 1
                            snapValue: 8
                            bounded: true

                            override: !active ? (value == "128" ? "Full" : (value == "0" ? "None" : "")) : ""

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
                            height: 4
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
                            height: 22
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
                    height: 25 + (25*5) + 3 + 3

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
                        color: COMMON.bg1
                        border.color: COMMON.bg4
                    }

                    Rectangle {
                        color: COMMON.bg2
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
                            height: 25
                            width: parent.width
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
                            height: 25
                            width: parent.width
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
                        color: COMMON.bg1
                        border.color: COMMON.bg4
                    }

                    Rectangle {
                        color: COMMON.bg2
                        border.color: COMMON.bg4
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 25


                        SIcon {
                            id: genSpinner
                            visible: GUI.isGenerating
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                            iconColor: null
                            opacity: 0.5
                            icon: "qrc:/icons/loading-big.svg"
                        }

                        RotationAnimator {
                            loops: Animation.Infinite
                            target: genSpinner
                            from: 0
                            to: 360
                            duration: 1000
                            running: parent.visible
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
                        color: COMMON.bg1
                        border.color: COMMON.bg4
                    }

                    Rectangle {
                        color: COMMON.bg2
                        border.color: COMMON.bg4
                        anchors.left: parent.left
                        anchors.right: parent.right
                        height: 25

                        SIcon {
                            id: conSpinner
                            visible: GUI.isConnecting
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                            iconColor: null
                            opacity: 0.5
                            icon: "qrc:/icons/loading-big.svg"
                            tooltip: "Connecting..."
                        }

                        RotationAnimator {
                            loops: Animation.Infinite
                            target: conSpinner
                            from: 0
                            to: 360
                            duration: 1000
                            running: parent.visible
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

                        SIconButton {
                            visible: backendMode.value == "Remote" && !GUI.isConnecting
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height
                            color: "transparent"
                            iconColor: COMMON.bg4
                            iconHoverColor: COMMON.bg7
                            tooltip: GUI.isConnected ? "Connected" : "Not connected"
                            icon: GUI.isConnected ? "qrc:/icons/lightning.svg" : "qrc:/icons/dash.svg"
                        }

                        MouseArea {
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.right: parent.right
                            width: height

                            onPressed: {
                                if(backendMode.value == "Remote") {
                                    console.log("HERE")
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
                            pointSize: 9.0
                        }

                        SInput {
                            visible: backendMode.value == "Remote"
                            height: 25
                            width: parent.width
                            label: "Password"
                            bindMap: GUI.backendParameters
                            bindKey: "password"
                            override: !active ? (value == "" ? "None" : "") : ""
                            pointSize: 9.0
                        }
                    }
                }
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
                    color: COMMON.bg1
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
                    color: COMMON.bg0_5
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

                ListView {
                    anchors.fill: parent
                    anchors.topMargin: 28
                    anchors.margins: 4
                    id: historyList
                    interactive: false
                    boundsBehavior: Flickable.StopAtBounds                   
                    width: parent.width
                    clip: true
                    model: Sql {
                        id: historySql
                        query: "SELECT rowid, id FROM history ORDER BY id DESC;"
                    }

                    Connections {
                        target: GUI
                        function onHistoryUpdated() {
                            historySql.reload()
                        }
                    }

                    ScrollBar.vertical: SScrollBarV { 
                        id: historyScrollBar
                        stepSize: 1/(4*Math.ceil(historySql.length))
                        policy: historyList.contentHeight > historyList.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: {
                            if(wheel.angleDelta.y < 0) {
                                historyScrollBar.increase()
                            } else {
                                historyScrollBar.decrease()
                            }
                        }
                    }

                    property var nextIndex: -1

                    delegate: Rectangle {
                        id: row
                        property var entry: GUI.getHistory(sql_id)
                        property var active: preview.locked && preview.target == entry

                        color: active ? COMMON.bg2_5 : (entryMouse.containsMouse ? COMMON.bg2 : COMMON.bg1_5)
                        height: 20
                        width: parent != null ? parent.width : 20

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
                    
                        SText {
                            id: indexLabel
                            anchors.left: parent.left
                            height: parent.height
                            width: 50
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: sql_rowid
                            pointSize: 9.0
                            color: COMMON.fg1_5
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
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: entry.label
                            pointSize: 9.0
                            color: COMMON.fg2
                        }

                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            height: 1
                            color: COMMON.bg4
                        }

                        MouseArea {
                            id: entryMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            property var startPosition: Qt.point(0,0)
                            property var dragged: false

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
                                            GUI.tabs.dragHistory(sql_id)
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
                visible: preview.visible
                anchors.fill: preview
                anchors.margins: -1
                color: COMMON.bg0

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    color: COMMON.bg1
                    border.color: COMMON.bg4
                    opacity: preview.locked ? 1.0 : 0.8
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 1
                    visible: preview.locked
                    color: "transparent"
                    opacity: 0.3
                    border.color: COMMON.accent(0)
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
                        preview.text = preview.target.content
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
        keyboardFocus.forceActiveFocus()
    }

    Item {
        id: keyboardFocus
        Keys.onPressed: {
            event.accepted = false
        }
        Keys.forwardTo: [main]
    }
}