import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtGraphicalEffects 1.15
import Qt.labs.platform 1.1

import gui 1.0

import "../style"

Rectangle {
    id: root
    property var area
    property var hDivider
    property var vDivider
    clip: true
    anchors.margins: 1
    color: COMMON.light ? COMMON.bg0_5 : COMMON.bg00

    property var active: GUI.tabs.current == root.area && GUI.tabs.areas.length > 1
    property var inactive: GUI.tabs.current != root.area && GUI.tabs.areas.length > 1

    function releaseFocus() {
        return;
    }

    function position() {
        var key = area.position;
        
        root.anchors.left = undefined
        root.anchors.right = undefined
        root.anchors.top = undefined
        root.anchors.bottom = undefined

        root.width = 0
        root.height = 0

        if(key.includes("T:")) {
            root.anchors.top = parent.top
        }
        if(key.includes("TC:")) {
            root.anchors.top = hDivider.verticalCenter
        }
        if(key.includes("B:")) {
            root.anchors.bottom = parent.bottom
        }
        if(key.includes("BC:")) {
            root.anchors.bottom = hDivider.verticalCenter
        }
        if(key.includes("L:")) {
            root.anchors.left = parent.left
        }
        if(key.includes("LC:")) {
            root.anchors.left = vDivider.horizontalCenter
        }
        if(key.includes("R:")) {
            root.anchors.right = parent.right
        }
        if(key.includes("RC:")) {
            root.anchors.right = vDivider.horizontalCenter
        }

        dropGrid.vertical = key.includes("T:") && key.includes("B:")
        dropGrid.horizonal = key.includes("L:") && key.includes("R:")
    }

    Connections {
        target: area
        function onPositionChanged() {
            root.position()
        }
    }

    Component.onCompleted: {
        root.position()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        property var startPosition: Qt.point(0,0)


        onPressed: {
            startPosition = Qt.point(mouse.x, mouse.y)
        }

        onPositionChanged: {
            if(pressedButtons & Qt.LeftButton) {
                var delta = Qt.point(mouse.x-startPosition.x, mouse.y-startPosition.y)
                if(Math.pow(delta.x*delta.x + delta.y*delta.y, 0.5) > 15) {
                    GUI.tabs.dragArea(root.area)
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: 5

        Row {
            id: tabBar
            anchors.left: parent.left
            anchors.top: parent.top
            height: 25
            spacing: -1
            
            Repeater {
                id: tabRepeater
                model: root.area.tabs
                Rectangle {
                    id: tab
                    property var current: root.area.current == index
                    property var working: modelData == GUI.workingTab
                    
                    width: tabLabel.width
                    height: 25

                    color: current ? (root.inactive ? COMMON.bg1_5 : COMMON.bg3) : COMMON.bg0_5
                    border.color: current ? (root.inactive ? COMMON.bg3 : COMMON.bg4) : COMMON.bg2_5
                    z: current ? 10 : 0

                    WorkingLine {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 1
                        height: 2
                        visible: working
                    }

                    AdvancedDropArea {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 40
                        anchors.leftMargin: -20
                        height: parent.height
                        filters: ['application/x-lineworks-position']

                        Rectangle {
                            visible: GUI.tabs.draggingTab
                            opacity: 0.5
                            anchors.left: parent.left
                            anchors.leftMargin: 20
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: parent.containsDrag ? 5 : 3
                            color: parent.containsDrag ? dropGrid.hoverColor : dropGrid.color
                        }

                        onDropped: {
                            GUI.tabs.dropTab(root.area, index)
                        }
                    }

                    Rectangle {
                        anchors.fill: tabLabel
                        visible: tabLabel.activeFocus
                        border.color: COMMON.bg4
                        color: COMMON.bg1
                        anchors.margins: 4
                    }

                    STextInput {
                        id: tabLabel
                        height: parent.height
                        leftPadding: 8
                        rightPadding: 8
                        verticalAlignment: Text.AlignVCenter
                        color: COMMON.fg1_5
                        pointSize: 10.2
                        text: modelData.name

                        onEditingFinished: {
                            modelData.name = tabLabel.text
                            root.releaseFocus()
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        property var startPosition: Qt.point(0,0)
                        visible: !tabLabel.activeFocus

                        Timer {
                            id: clickCooldown
                            interval: 250
                        }

                        onPressed: {
                            startPosition = Qt.point(mouse.x, mouse.y)
                            area.current = index
                            if(pressedButtons & Qt.RightButton) {
                                tabMenu.popup()
                            } else {
                                if(clickCooldown.running) {
                                    tabLabel.forceActiveFocus()
                                } else {
                                    clickCooldown.start()
                                }
                            }
                        }

                        onPositionChanged: {
                            if(pressedButtons & Qt.LeftButton) {
                                var delta = Qt.point(mouse.x-startPosition.x, mouse.y-startPosition.y)
                                if(Math.pow(delta.x*delta.x + delta.y*delta.y, 0.5) > 15) {
                                    GUI.tabs.dragTab(modelData)
                                }
                            }
                        }
                    }

                    SMenu {
                        id: tabMenu
                        width: 80
                        clipShadow: true
                        SMenuItem {
                            text: "Save"
                            onPressed: {
                                saveDialog.show(modelData)
                            }
                        }
                        SMenuItem {
                            text: "Rename"
                            onPressed: {
                                tabLabel.forceActiveFocus()
                            }
                        }
                        SMenuItem {
                            text: "Delete"
                            onPressed: {
                                deleteDialog.show(modelData)
                            }
                        }
                    }
                }
            }

            Rectangle {
                height: 25
                width: 25
                color: COMMON.bg0
                border.color: COMMON.bg2

                SIconButton {
                    color: "transparent"
                    anchors.fill: parent
                    anchors.margins: 1
                    icon: "qrc:/icons/plus.svg"
                    iconColor: COMMON.bg4
                    iconHoverColor: COMMON.bg7

                    onPressed: {
                        root.area.newTab()
                    }
                }
            }
        }

        AdvancedDropArea {
            anchors.left: tabBar.right
            anchors.leftMargin: -45
            anchors.right: parent.right
            anchors.top: tabBar.top
            height: 24
            filters: ['application/x-lineworks-position']
            z: 100

            Rectangle {
                visible: GUI.tabs.draggingTab
                opacity: 0.5
                anchors.left: parent.left
                anchors.leftMargin: -width + 20
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.containsDrag ? 5 : 3
                color: parent.containsDrag ? dropGrid.hoverColor : dropGrid.color
            }
            
            onDropped: {
                GUI.tabs.dropTab(root.area, -1)
            }
        }

        Rectangle {
            anchors.top: tabBar.bottom
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: -1
            color: COMMON.light ? COMMON.bg1 : COMMON.bg0
            border.color: COMMON.bg4
            clip: true

            Item {
                anchors.fill: parent
                anchors.margins: 1
                clip: true
                RectangularGlow {
                    anchors.centerIn: parent
                    width: Math.min(600, parent.width)
                    height: parent.height-2
                    glowRadius: 8
                    opacity: 0.15
                    spread: 0.2
                    color: "black"
                    cornerRadius: 10
                }

                StackLayout {
                    anchors.fill: parent
                    anchors.topMargin: -1
                    anchors.bottomMargin: -1
                    currentIndex: root.area.current
                    Repeater {
                        model: ArrayModel {
                            source: root.area != undefined ? root.area.tabs : []
                            unique: true
                        }
                        Item {
                            Rectangle {
                                id: content
                                color: COMMON.light ? COMMON.bg00 : COMMON.bg1
                                border.color: COMMON.bg4
                                border.width: 1
                                anchors.centerIn: parent
                                width: Math.min(600, parent.width+2)
                                height: parent.height
                                anchors.margins: 10
                                anchors.leftMargin: 0
                                anchors.rightMargin: 0

                                property var working: modelData == GUI.workingTab

                                function focus() {
                                    textArea.forceActiveFocus()
                                }

                                Connections {
                                    target: root.area
                                    function onCurrentChanged() {
                                        if(root.area.current == index) {
                                            content.focus()
                                        }
                                    }
                                }

                                Connections {
                                    target: GUI.tabs
                                    function onCurrentChanged() {
                                        if(root.area == GUI.tabs.current && root.area.current == index) {
                                            content.focus()
                                        }
                                    }
                                }

                                Item {
                                    id: underlays
                                    anchors.fill: textArea
                                    clip: true
                                    
                                }

                                TabTextArea {
                                    id: textArea
                                    anchors.fill: parent
                                    area.padding: 10
                                    area.leftPadding: 12
                                    area.rightPadding: 16
                                    area.selectionColor: root.inactive ? COMMON.accent(0, 0.0, 0.4) : COMMON.accent(0, 0.7, 0.7)

                                    tab: modelData
                                    inactive: root.inactive
                                    working: content.working

                                    function clean(text) {
                                        return modelData.clean(text)
                                    }

                                    function insert(index, text) {
                                        area.insert(index, text)
                                        textArea.ensureVisible(index+text.length)
                                    }


                                    Timer {
                                        id: alignTimer
                                        interval: 1
                                        onTriggered: {
                                            textArea.align()
                                            textArea.area.cursorVisible = true
                                        }
                                    }

                                    function align() {
                                        // sync marker and cursor alignment when they are visibly in the same spot
                                        if(modelData.marker != -1 && modelData.marker + 1 == textArea.area.cursorPosition) {
                                            textArea.area.cursorPosition -= 1
                                        }
                                    }

                                    function layout() {
                                        marker.layout()
                                        textArea.stream.update()
                                    }

                                    property var setCursor: null

                                    onTextChanged: {
                                        if(area.text[area.text.length-1] == "\u00AD") {
                                            if(!moving) {
                                                area.remove(area.text.length-1,area.text.length)
                                            }
                                        } else if(area.text.includes("\u00AD") || modelData.marker == -1) { //has marker
                                            modelData.content = area.text
                                        } else if(area.cursorPosition == area.text.length) { // move marker to end
                                            modelData.content = area.text
                                        } else { //move marker to cursor
                                            if(!moving) {
                                                area.insert(area.cursorPosition, "\u00AD")
                                            }
                                        }
                                        
                                        textArea.spelling.update()
                                        layout()
                                        return
                                    }

                                    area.onTextChanged: {
                                        textArea.lock = false
                                        if(textArea.setCursor != null) {
                                            if(textArea.area.text.length < textArea.setCursor) {
                                                textArea.area.cursorPosition = textArea.area.text.length
                                            } else {
                                                textArea.area.cursorPosition = textArea.setCursor
                                            }
                                            textArea.setCursor = null
                                        }
                                    }

                                    area.onCursorPositionChanged: {
                                        textArea.area.cursorVisible = false
                                        // on keyboard input the cursor position changes before text changes
                                        // need to wait an instant
                                        alignTimer.start()
                                    }

                                    Connections {
                                        target: modelData

                                        function onMarkerChanged() {
                                            textArea.layout()
                                        }

                                        function onFocus() {
                                            textArea.forceActiveFocus()
                                        }

                                        function onSet() {
                                            if(!GUI.isGenerating) {
                                                modelData.moveMarker(textArea.area.cursorPosition)
                                            }
                                            textArea.ensureVisible(textArea.area.cursorPosition)
                                        }

                                        function onRemove(start, end) {
                                            var c = textArea.area.cursorPosition
                                            if(c > start) {
                                                if(c < end) {
                                                    textArea.setCursor = start
                                                } else {
                                                    textArea.setCursor = c - (end-start)
                                                }
                                            } else {
                                                textArea.setCursor = c
                                            }

                                            textArea.area.remove(start, end)
                                        }

                                        function onInsert(index, text) {
                                            textArea.insert(index, text)
                                        }

                                        function onMove(oldPos, newPos) {
                                            textArea.moving = true

                                            if(oldPos != -1) {
                                                textArea.area.remove(oldPos, oldPos+1)
                                            }
                                            if(newPos != -1) {
                                                textArea.area.insert(newPos, "\u00AD")
                                                textArea.moving = false
                                                textArea.area.cursorPosition = newPos
                                            } else {
                                                textArea.moving = false
                                                textArea.area.cursorPosition = textArea.area.text.length
                                            }
                                        }

                                        function debugPrint(text) {
                                            var chrs = []
                                            for(var i = 0; i < text.length; i++) {
                                                chrs.push(text.charCodeAt(i))
                                            }
                                            console.log(chrs)
                                        } 

                                        function onContentChanged() {
                                            if(modelData.content != textArea.text) {
                                                console.log("DESYNC")
                                                textArea.text = modelData.content
                                            }
                                        }
                                    }

                                    Component.onCompleted: {
                                        modelData.setHighlighting(area.textDocument)
                                        area.insert(0, modelData.initial)
                                        area.cursorPosition = 0
                                    }

                                    MouseArea {
                                        id: textMouseArea
                                        anchors.fill: parent

                                        onPressed: {
                                            if ((mouse.button == Qt.LeftButton) && (mouse.modifiers & Qt.ControlModifier)) {
                                                var position = textArea.area.mapFromItem(textMouseArea, Qt.point(mouse.x, mouse.y))
                                                var p = textArea.area.positionAt(position.x, position.y)
                                                if(p != modelData.marker && !GUI.isGenerating) {
                                                    modelData.moveMarker(p)
                                                }
                                            } else {
                                                mouse.accepted = false
                                            }
                                        }
                                    }
                                }

                                Item {
                                    id: overlays
                                    anchors.fill: textArea
                                    clip: true
                                    MarkerOverlay {
                                        id: marker
                                        tab: modelData
                                        textArea: textArea
                                        inactive: root.inactive
                                        working: content.working
                                    }
                                }

                                Rectangle {
                                    visible: root.active
                                    anchors.fill: textArea
                                    color: "transparent"
                                    opacity: 0.3
                                    border.color: COMMON.accent(0)
                                }
                            }
                        }
                    }
                }
            }
            
            DropGrid {
                id: dropGrid
                anchors.fill: parent
                visible: GUI.tabs.draggingTab || GUI.tabs.draggingArea

                onDropped: {
                    if(GUI.tabs.draggingTab) {
                        GUI.tabs.dropTab(root.area, position)
                    } else {
                        GUI.tabs.dropArea(root.area, position)
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                onPressed: {
                    mouse.accepted = false
                    GUI.tabs.current = root.area
                }
            }
        }
    }

    FileDialog {
        id: saveDialog
        nameFilters: ["Text files (*.txt)"]
        property var tab: null
        fileMode: FileDialog.SaveFile

        function show(tab) {
            saveDialog.tab = tab
            saveDialog.open()
        }

        onAccepted: {
            GUI.tabs.saveTab(tab, file)
        }
    }

    SDialog {
        id: deleteDialog
        title: "Confirmation"
        standardButtons: Dialog.Ok | Dialog.Cancel
        modal: true
        property var tab: null

        function show(tab) {
            deleteDialog.tab = tab
            deleteDialog.open()
        }

        height: Math.max(80, deleteMessage.height + 60)
        width: 300

        SText {
            id: deleteMessage
            anchors.centerIn: parent
            padding: 5
            text: "Delete %1?".arg(deleteDialog.tab != null ? deleteDialog.tab.name : "")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            width: parent.width
            wrapMode: Text.Wrap
            color: COMMON.fg1
        }       

        onAccepted: {
            GUI.tabs.deleteTab(tab)
        }

        onClosed: {
            root.forceActiveFocus()
        }
    }
}