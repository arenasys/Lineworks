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

                    /*Rectangle {
                        color: "black"
                        opacity: current ? (root.inactive ? 0.2 : 0.0) : 0.35
                        anchors.fill: parent
                    }*/

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
            }

            StackLayout {
                anchors.fill: parent
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
                            width: Math.min(600, parent.width)
                            height: parent.height
                            anchors.margins: 10
                            anchors.leftMargin: 0
                            anchors.rightMargin: 0
                            clip: true

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
                                id: last
                                signal layout()

                                Repeater {
                                    model: ArrayModel {
                                        id: indicators
                                        source: modelData.last
                                        unique: true
                                    }
                                    
                                    Rectangle {
                                        id: indicator
                                        function layout() {
                                            var p = modelData

                                            var l = textArea.area.text.length

                                            if(p.x > l || p.y > l) {
                                                indicator.position = Qt.rect(0,0,0,0)
                                                return
                                            }

                                            var start = textArea.getPositionRectangle(p.x)
                                            var end = textArea.getPositionRectangle(p.y)

                                            if(start.y != end.y) {
                                                var end_tmp = textArea.getPositionRectangle(p.y-1)
                                                if(start.y != end_tmp.y) {
                                                    var start_tmp = textArea.getPositionRectangle(p.x+1)
                                                    if(start_tmp.y == end_tmp.y) {
                                                        start = start_tmp
                                                    } else {
                                                        indicator.position = Qt.rect(0,0,0,0)
                                                        return
                                                    }
                                                } else {
                                                    end = end_tmp
                                                }
                                            }
                                            indicator.position = Qt.rect(start.x, start.y, end.x-start.x, start.height)
                                            //console.log(textArea.area.text.slice(p.x, p.y), indicator.position)
                                        }

                                        Connections {
                                            target: last
                                            function onLayout() {
                                                layout()
                                            }
                                        }

                                        Component.onCompleted: {
                                            layout()
                                        }

                                        property var position: Qt.rect(0,0,0,0)
                                        property var vertical: position.width == 0
                                        property var value: 1

                                        visible: position.height != 0

                                        x: position.x-1
                                        y: vertical ? position.y : (position.y + 7)
                                        width: vertical ? 10 : (position.width+2)
                                        height: vertical ? position.height : 10
                                        opacity: 1.0
                                        radius: 5
                                        color: COMMON.accent(0, 0.5, 0.4, value)

                                        Timer {
                                            running: true
                                            repeat: true
                                            interval: 50
                                            onTriggered: {
                                                if(index == indicators.count-1 && content.working) {
                                                    return
                                                }
                                                parent.value -= 0.1
                                                if(parent.value <= 0) {
                                                    parent.value = 0
                                                }
                                            }
                                        }

                                        Rectangle {
                                            visible: index == 0
                                            x: 0
                                            y: vertical ? 0 : -7
                                            width: 2
                                            height: 20
                                            opacity: 0.8
                                            color: root.inactive && !content.working ? COMMON.fg3 : COMMON.accent(0.0, 0.7, 0.4)
                                        }
                                    }
                                }
                            }

                            STextArea {
                                id: textArea
                                anchors.fill: parent
                                area.padding: 10
                                area.leftPadding: 12
                                area.rightPadding: 12
                                area.selectionColor: root.inactive ? COMMON.accent(0, 0.0, 0.4) : COMMON.accent(0, 0.7, 0.7)

                                function clean(text) {
                                    return modelData.clean(text)
                                }

                                function insert(index, text) {
                                    var lock = control.atYEnd
                                    area.insert(index, text)
                                    if(lock && control.contentHeight > control.height) {
                                        control.contentY = control.contentHeight-control.height
                                    }
                                }

                                function layout() {
                                    if(modelData.marker != -1) {
                                        if(area.length >= modelData.marker) {
                                            marker.position = textArea.getPositionRectangle(modelData.marker)
                                        }
                                    } else {
                                        marker.position = textArea.getPositionRectangle(textArea.area.text.length)
                                    }
                                    last.layout()
                                }

                                property var setCursor: null

                                onTextChanged: {
                                    modelData.content = area.text
                                    layout()
                                }

                                area.onTextChanged: {
                                    if(textArea.setCursor != null) {
                                        textArea.area.cursorPosition = textArea.setCursor
                                        textArea.setCursor = null
                                    }
                                }

                                Connections {
                                    target: modelData
                                    function onInsert(index, text) {
                                        textArea.insert(index, text)
                                    }
                                    function onContentChanged() {
                                        if(modelData.content != textArea.text) {
                                            textArea.setCursor = textArea.area.cursorPosition
                                            textArea.text = modelData.content
                                        }
                                    }
                                }

                                Component.onCompleted: {
                                    modelData.setHighlighting(area.textDocument)
                                    textArea.insert(0, modelData.initial)
                                }

                                MouseArea {
                                    id: textMouseArea
                                    anchors.fill: parent

                                    onPressed: {
                                        if ((mouse.button == Qt.LeftButton) && (mouse.modifiers & Qt.ControlModifier)) {
                                            var position = textArea.area.mapFromItem(textMouseArea, Qt.point(mouse.x, mouse.y))
                                            var p = textArea.area.positionAt(position.x, position.y)
                                            if(p != modelData.marker) {
                                                modelData.moveMarker(p)
                                            }
                                        } else {
                                            mouse.accepted = false
                                        }
                                    }
                                }

                                Rectangle {
                                    id: marker
                                    property var position: Qt.rect(0,0,0,0)
                                    x: position.x-1
                                    y: position.y
                                    width: 2
                                    height: position.height
                                    visible: height != 0

                                    color: root.inactive && !content.working ? COMMON.fg2 : COMMON.accent(0, 0.8)

                                    opacity: markerMouseArea.active || root.inactive ? 0.8 : blink

                                    MouseArea {
                                        id: markerMouseArea
                                        anchors.fill: parent
                                        anchors.leftMargin: -5
                                        anchors.rightMargin: -5
                                        hoverEnabled: true

                                        property var active: containsMouse || dragging
                                        property var dragging: false
                                        property var startPosition: Qt.point(0,0)
                                        property var markerStartPosition: Qt.point(0,0)

                                        onPressed: {
                                            startPosition = textArea.area.mapFromItem(markerMouseArea, Qt.point(mouse.x, mouse.y))
                                            markerStartPosition = textArea.area.mapFromItem(textArea, Qt.point(marker.position.x, marker.position.y))
                                        }

                                        onReleased: {
                                            dragging = false
                                        }

                                        Timer {
                                            id: cooldown
                                            interval: 10
                                        }

                                        onPositionChanged: {
                                            var mousePosition = textArea.area.mapFromItem(markerMouseArea, Qt.point(mouse.x, mouse.y))
                                            if(pressedButtons & Qt.LeftButton) {
                                                var delta = Qt.point(mousePosition.x-startPosition.x, mousePosition.y-startPosition.y)
                                                if(!dragging) {
                                                    if(Math.pow(delta.x*delta.x + delta.y*delta.y, 0.5) > 5) {
                                                        dragging = true
                                                    }
                                                } else {
                                                    if(!cooldown.running) {
                                                        var boxPosition = textArea.mapFromItem(markerMouseArea, Qt.point(mouse.x, mouse.y))
                                                        if(boxPosition.y < 0) {
                                                            textArea.scrollBar.decrease()
                                                            cooldown.start()
                                                        } else if (boxPosition.y > textArea.height) {
                                                            textArea.scrollBar.increase()
                                                            cooldown.start()
                                                        }
                                                    }

                                                    var x = Math.floor(markerStartPosition.x + delta.x)
                                                    var dy = Math.floor(delta.y/marker.height) * marker.height
                                                    var y = Math.floor(markerStartPosition.y + dy + marker.height/2)
                                                    var p = textArea.area.positionAt(x, y)

                                                    if(p != modelData.marker) {
                                                        modelData.moveMarker(p)
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    property var blink: 0.8

                                    NumberAnimation on blink {
                                        id: animation;
                                        from: 1.0
                                        to: 0.2
                                        duration: GUI.isGenerating ? 500 : 1000
                                        loops: Animation.Infinite
                                        running: true
                                        onDurationChanged: {
                                            restart()
                                        }
                                    }
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