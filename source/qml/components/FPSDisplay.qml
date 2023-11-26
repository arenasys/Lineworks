import QtQuick 2.0
import QtQuick.Window 2.2

import gui 1.0

Item {
    id: root
    property int frameCounter: 0
    property int frameCounterAvg: 0
    property int counter: 0
    property int fps: 0
    property int fpsAvg: 0

    width:  15
    height: 15

    Image {
        id: spinnerImage
        anchors.fill: parent
        source: "qrc:/icons/loading-big.svg"
        opacity: 0.0
        NumberAnimation on rotation {
            from: 0
            to: 360
            duration: 800
            loops: Animation.Infinite
        }
        onRotationChanged: frameCounter++;
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 0
        anchors.verticalCenter: spinnerImage.verticalCenter
        color: COMMON.fg2
        font.pixelSize: 10
        text: root.fps + " fps"
    }

    Timer {
        interval: 2000
        repeat: true
        running: true
        onTriggered: {
            frameCounterAvg += frameCounter;
            root.fps = frameCounter/2;
            counter++;
            frameCounter = 0;
            if (counter >= 3) {
                root.fpsAvg = frameCounterAvg/(2*counter)
                frameCounterAvg = 0;
                counter = 0;
            }
        }
    }
}