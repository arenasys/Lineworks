import QtQuick 2.12
import QtQuick.Controls 2.12
import QtGraphicalEffects 1.15

import gui 1.0

Menu {
    id: root
    readonly property real menuItemSize: 20
    opacity: count != 0 ? 1.0 : 0.0
    topPadding: 2
    bottomPadding: 2
    property var clipShadow: false

    delegate: SMenuItem {
        menuItemSize: root.menuItemSize
    }

    background: Item {
        implicitWidth: 150
        implicitHeight: menuItemSize

        Item {
            clip: root.clipShadow
            anchors.fill: parent
            anchors.margins: -10
            anchors.topMargin: 0
            RectangularGlow {
                anchors.fill: parent
                anchors.margins: 10
                anchors.topMargin: 0
                glowRadius: 5
                opacity: 0.5
                color: "black"
                cornerRadius: 10
            }
        }
        
        Rectangle {
            anchors.fill: parent
            color: COMMON.bg3
            border.width: 1
            border.color: COMMON.bg4
        }
    }

    
}
