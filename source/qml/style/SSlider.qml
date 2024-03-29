import QtQuick 2.15
import QtQuick.Controls 2.15

import gui 1.0

Item {
    id: root
    height: 30
    property var mini: height == 20

    property var label: "Label"
    property var tooltip: ""
    property var override: ""
    property double value: 0
    property var defaultValue: null
    property double minValue: 0
    property double maxValue: 100
    property double precValue: 0
    property double incValue: 1
    property var snapValue: null
    property var labelWidth: 70
    property var disabled: false
    property var overlay: root.disabled
    property alias active: valueInput.activeFocus

    property var validator: RegExpValidator {
        regExp: /|[+-]?([0-9]+([.][0-9]*)?|[.][0-9]+)/
    }

    property var bounded: true
    property var minBounded: true

    onBoundedChanged: {
        if(root.value > root.maxValue) {
            root.value = root.maxValue
        }
    }

    onMinBoundedChanged: {
        if(root.value < root.minValue) {
            root.value = root.minValue
        }
    }

    property alias control: control

    property variant bindMap: null
    property var bindKey: null
    property var bindKeyLabel: null

    signal selected()
    signal finished()

    function label_display(text) {
        return text
    }

    Connections {
        target: bindMap
        function onUpdated(key) {
            if(key == bindKey || key == bindKeyLabel) {
                var v = root.bindMap.get(root.bindKey)
                if(v != root.value) {
                    root.value = v
                }
                if(root.bindKeyLabel != null) {
                    root.label = root.bindMap.get(root.bindKeyLabel);
                }
            }
        }
    }

    onBindMapChanged: {
        var v = root.bindMap.get(root.bindKey)
        if(v != root.value) {
            root.value = v
        }
    }

    Component.onCompleted: {
        if(root.bindMap != null && root.bindKey != null) {
            root.value = root.bindMap.get(root.bindKey)
        }

        if(root.defaultValue == null) {
            root.defaultValue = root.value;
        }

        if(root.bindKeyLabel != null) {
            root.label = root.bindMap.get(root.bindKeyLabel);
        }
    }

    onValueChanged: {
        if(root.bindMap != null && root.bindKey != null) {
            root.bindMap.set(root.bindKey, root.value)
        }
    }

    function update(pos) {
        var value = pos*(root.maxValue-root.minValue) + root.minValue
        value = parseFloat(value.toFixed(root.precValue))

        if(root.snapValue != null) {
            if(value != root.minValue) {
                value = Math.round(value/root.snapValue) * root.snapValue;
            }
        }

        if(value != root.value && !root.disabled) {
            root.value = value
        }
    }

    Rectangle {
        id: control
        anchors.fill: parent
        anchors.margins: 2
        anchors.bottomMargin: 0

        color: (COMMON.light || COMMON.classic)  ? COMMON.bg2 : COMMON.bg2_5

        MouseArea {
            id: mouseArea
            anchors.left: parent.left
            anchors.right: spinnerControls.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: -2
            anchors.leftMargin: 0
            hoverEnabled: true
            preventStealing: true

            function update() {
                var pos = mouseX
                if(root.minBounded) {
                    pos = Math.max(0, mouseX)
                }
                if(root.bounded) {
                    pos = Math.min(width, pos)
                }
                root.update(pos/width)
                root.selected()
            }

            onPressed: {
                mouseArea.update()
            }

            onPositionChanged: {
                if(pressed) {
                    mouseArea.update()
                }
            }

            onReleased: {
                root.finished()
            }
        }

        Item {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: spinnerControls.left
            clip: true

            SText {
                id: labelText
                text: root.label_display(root.label)
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                leftPadding: 5
                rightPadding: 5
                width: root.labelWidth
                verticalAlignment: Text.AlignVCenter
                pointSize: root.mini ? 7.85 : COMMON.pointLabel
                color: COMMON.fg1_5
                monospace: false
            }

            Rectangle {
                id: indicator
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: COMMON.bg3_5
                width: Math.min((mouseArea.width) * (root.value - root.minValue)/(root.maxValue-root.minValue), control.width)
                clip: true

                Rectangle {
                    width: 1
                    height: parent.height
                    anchors.right: parent.right
                    color: COMMON.bg4
                }

                SText {
                    id: indicatorLabel
                    text: root.label
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    leftPadding: 5
                    rightPadding: 5
                    width: root.labelWidth
                    verticalAlignment: Text.AlignVCenter
                    pointSize: root.mini ? 7.85 : COMMON.pointLabel
                    color: COMMON.fg1_3
                    monospace: false
                }
            }
        }

        SToolTip {
            id: infoToolTip
            x: 0
            visible: !disabled && tooltip != "" && mouseArea.containsMouse && mouseArea.mouseX < root.width/3
            delay: 100
            text: tooltip
        }

        Item {
            anchors.right: spinnerControls.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 2
            width: (spinnerControls.x - labelText.contentWidth - 10)
            clip: true

            Rectangle {
                visible: valueInput.activeFocus
                width: valueInput.contentWidth + 10
                anchors.right: valueInput.right
                anchors.top: valueInput.top
                anchors.bottom: valueInput.bottom
                anchors.margins: root.mini ? 0 : 1
                border.color: COMMON.bg4
                color: COMMON.bg1
            }

            STextInput {
                id: valueInput
                height: parent.height
                width: contentWidth + 10
                anchors.right: parent.right
                
                color: COMMON.fg1
                pointSize: root.mini ? 7.7 : COMMON.pointValue
                activeFocusOnPress: false
                leftPadding: 5
                rightPadding: 5
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                text: root.value.toFixed(root.precValue)
                validator: root.validator
                onEditingFinished: {
                    if(text == "") {
                        root.value = parseFloat(root.defaultValue)
                        text = root.defaultValue
                    } else {
                        var value = parseFloat(text)
                        var bottom = root.minValue
                        var top = root.bounded ? root.maxValue : 2147483647.0
                        if(value <= top && value >= bottom) {
                            root.value = value
                        }
                    }
                    root.forceActiveFocus()
                    GUI.resetFocus()
                }
                onActiveFocusChanged: {
                    if(!activeFocus) {
                        valueInput.text =  Qt.binding(function() { return root.value.toFixed(root.precValue) })
                    }
                }
                
                Keys.onPressed: {
                    switch(event.key) {
                        case Qt.Key_Escape:
                            if(root.defaultValue != null) {
                                if(root.defaultValue == "-1") {
                                    root.value = ""
                                    text = ""
                                } else {
                                    root.value = root.defaultValue
                                    text = root.defaultValue.toFixed(root.precValue) 
                                }
                            }
                            root.forceActiveFocus()
                            GUI.resetFocus()
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    visible: !valueInput.activeFocus
                    propagateComposedEvents: true

                    onPressed: {
                        if(valueInput.text == "-1" && valueInput.text == root.defaultValue) {
                            valueInput.text = ""
                        }
                        valueInput.forceActiveFocus()
                        valueInput.selectAll()
                    }
                }
            }

            Rectangle {
                visible: overrideText.visible
                anchors.fill: overrideText
                color: indicator.width == 0 ? COMMON.bg2_5 : COMMON.bg3_5
                anchors.margins: 2
            }

            SText {
                id: overrideText
                anchors.fill: parent

                color: COMMON.fg1
                pointSize: COMMON.pointLabel
                monospace: true
                rightPadding: 7

                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignRight
                
                text: root.override
                visible: root.override != ""
            }
        }

        Item {
            id: spinnerControls
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            width: 8
            
            Rectangle {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.bottom: parent.verticalCenter
                anchors.margins: 1
                anchors.bottomMargin: 0
                //height: parent.height/2
                width: 8
                color: COMMON.bg3_5

                Canvas {
                    id: upperCanvas
                    anchors.fill: parent
                    renderStrategy: Canvas.Cooperative

                    onVisibleChanged: {
                        requestPaint()
                    }

                    onHeightChanged: {
                        requestPaint()
                    }

                    Connections {
                        target: COMMON
                        function onSchemeChanged() {
                            upperCanvas.requestPaint()
                        }
                    }

                    onPaint: {
                        var context = getContext("2d");
                        var o = root.mini ? 2.75 : 1.5;
                        var f = root.mini ? 0.75 : -1;
                        context.reset();
                        context.moveTo(o, f+height-o);
                        context.lineTo(width-o, f+height-o);
                        context.lineTo(width / 2,f+height-(width-o));
                        context.lineTo(o,f+height-o);
                        context.closePath();
                        context.fillStyle = (COMMON.light || COMMON.classic) ?  COMMON.bg6 : COMMON.bg5;
                        context.fill();
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true

                    onPressed: {
                        root.value = Math.min(root.value + root.incValue, root.maxValue)
                    }
                }

            }

            Rectangle {
                anchors.top: parent.verticalCenter
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.margins: 1
                anchors.topMargin: 0
                width: 8
                color: COMMON.bg3_5

                Canvas {
                    id: lowerCanvas
                    anchors.fill: parent
                    renderStrategy: Canvas.Cooperative

                    onVisibleChanged: {
                        requestPaint()
                    }

                    onHeightChanged: {
                        requestPaint()
                    }

                    Connections {
                        target: COMMON
                        function onSchemeChanged() {
                            lowerCanvas.requestPaint()
                        }
                    }

                    onPaint: {
                        var context = getContext("2d");
                        var o = root.mini ? 2.75 : 1.5;
                        var f = root.mini ? -0.75 : 1;
                        context.reset();
                        context.moveTo(o, f+o);
                        context.lineTo(width-o, f+o);
                        context.lineTo(width / 2, f+width-o);
                        context.lineTo(o,f+o);
                        context.closePath();
                        context.fillStyle = (COMMON.light || COMMON.classic) ?  COMMON.bg6 : COMMON.bg5;
                        context.fill();
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true

                    onPressed: {
                        root.value = Math.max(root.value - root.incValue, root.minValue)
                    }
                }
            }
        }

        Rectangle {
            visible: COMMON.light
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: spinnerControls.left
            anchors.rightMargin: 1
            width: 1
            color: COMMON.bg4
        }

        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.color: COMMON.bg4
        }
    }
    Rectangle {
        anchors.fill: control
        visible: root.overlay
        color: "#90101010"
        
        opacity: COMMON.light ? 0.2 : 1.0
    }

    MouseArea {
        anchors.fill: parent
        visible: root.disabled
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        SToolTip {
            visible: root.tooltip != "" && parent.containsMouse
            delay: 100
            text: root.tooltip
            color: "#f0101010"
        }
    }
    
    Rectangle {
        anchors.fill: control
        visible: root.disabled
        
        opacity: COMMON.light ? 0.2 : 1.0
        color: "#60101010"
    }
}